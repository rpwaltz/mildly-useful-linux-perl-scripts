#!/usr/bin/perl

use Geo::IP;

open (MTR, "-|",'mtr -rw municipalonlinepayments.com');

my @mtr_array;
my $mtr_array_index = 0;

while (<MTR>) {
	my $mtr_line = $_;
	@mtr_line_match_array = ($mtr_line =~ (/^(?:([^\s]+)\s+)$/)) ;
	$mtr_array[$mtr_array_index] = @mtr_line_match_array;
	++$mtr_array_index;
}

my $i;
for ($i = 0; $i <= $#mtr_array; ++$i) {
	my $mtr_line = $mtr_array[$i];
	print "$i $mtr_line \n";
}

