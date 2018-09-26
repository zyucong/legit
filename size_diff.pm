#!/usr/bin/perl -w

package size_diff;
use strict;
use warnings;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(difference);

sub difference {
	my ($file1, $file2) = @_;
	return 1 if (-s "$file1" != -s "$file2");
	return 0;
}

1;
