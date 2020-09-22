#!/usr/bin/perl

use Geo::IP;
use Text::CSV qw( csv );
use Socket;
use Getopt::Long 'HelpMessage';

GetOptions(
    'hostname=s'      => \my $hostname,
    'output_folder=s' => \( my $output_folder = undef ),
    'help'            => sub { HelpMessage(0) },
) or HelpMessage(1);

HelpMessage(1) unless $hostname;

# GeoIP2-perl might have more up to date entries than Geo::IP, but GeoIP2 needs an account on maxmind
# see for details of downloading free databse https://dev.maxmind.com/geoip/geoip2/geolite2/
# maybe even better is to use web client access instead of downloading database?

my $gi = Geo::IP->open( '/usr/share/GeoIP/GeoIP.dat', GEOIP_STANDARD );

my $mtr_command = 'mtr --no-dns -rw ' . $hostname;

open( MTR, "-|", $mtr_command );

my @mtr_array;
my $mtr_array_index = 0;

# parse mtr command output into an array, massaging some data along the way so that CSV output file will be clean
while (<MTR>) {
    my $mtr_line = $_;

    # print $mtr_line . "\n";
    $mtr_line =~ s/^\s+(.+)$/$1/g;
    my @mtr_line_match_array = split( /\s+/, $mtr_line );
    next if ( $#mtr_line_match_array < 3 );
    if ( $mtr_line_match_array[0] =~ /HOST:/ ) {
        $mtr_line_match_array[0] =~ s/HOST:/HOP/;
        $mtr_line_match_array[1] = 'IP';
        my $hostname_index = scalar(@mtr_line_match_array);
        $mtr_line_match_array[$hostname_index] = 'HostName';
        my $location_index = scalar(@mtr_line_match_array);
        $mtr_line_match_array[$location_index] = 'Location';
    }
    elsif ( $mtr_line_match_array[0] =~ /\d/ ) {
        $mtr_line_match_array[0] =~ s/[^\d]//g;
    }

    $mtr_array[$mtr_array_index] = \@mtr_line_match_array;
    ++$mtr_array_index;
}

#flip through the array, extracting either an ip or hostname, and getting the country code. add country code to mtr array
for ( my $i = 1 ; $i <= $#mtr_array ; ++$i ) {
    my $mtr_line = $mtr_array[$i];
    my $country  = undef;
    my $name     = undef;
    if ( $mtr_line->[1] =~ /^(?:\d+)\.(?:\d+)\.(?:\d+)\.(?:\d+)$/ ) {
        my $ip = $mtr_line->[1];
        $name    = gethostbyaddr( inet_aton($ip), AF_INET );
        $country = $gi->country_code_by_addr($ip);
    }
    else {
        die( "not an ip address: " . $mtr_line[1] );
    }
    my $hostname_index = scalar( @{$mtr_line} );
    $mtr_line->[$hostname_index] = $name;
    $country_index = scalar( @{$mtr_line} );

    $country = 'N/A' unless ( defined($country) );
    $mtr_line->[$country_index] = $country;

}

my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
  localtime();

$output_folder = "${output_folder}/" if defined($output_folder);

my $filename =
"${output_folder}Routing_with_Location_${year}${mon}${mday}${hour}${min}${sec}.csv";

open my $csv_outputFileHandle, ">:encoding(utf8)", $filename
  or die "failed to create $filename: $!";
my $outfile;
my $csv = Text::CSV->new(
    {
        eol         => "\012",
        sep_char    => ";",
        escape_char => "\\",
        quote_char  => "\""
    }
);
for ( my $i = 0 ; $i <= $#mtr_array ; ++$i ) {
    my $mtr_line = $mtr_array[$i];
    $csv->print( $csv_outputFileHandle, $mtr_line );
}

=head1 NAME

makeRoutingAndLocationCSV.pl - produce a CSV file containing routing and location information for a hostname destination

=head1 SYNOPSIS

	--hostname,-h         Hostname to trace
	--output_folder,-o    Folder destination to output CSV file
	--help,-h             Print this help

=head1 VERSION

1.00

=cut
