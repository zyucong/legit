#!/usr/bin/perl -w

package detect_change;
use strict;
use warnings;
use File::Compare;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(any_change change_after_add diff_to_repo);

sub diff_to_repo {
	my ($file, $version) = @_;
	my $filename = ".legit/index/$file";
	my $file_in_repo = ".legit/version.$version/$file";
	return 1 if (compare("$filename", "$file_in_repo"));
	return 0;
}

sub change_after_add {
	my ($file) = @_;
	my $filename = "./$file";
	my $file_in_index = ".legit/index/$file";
	return 1 if (! -e $file_in_index);
	return 1 if (compare("$filename", "$file_in_index") == 1);
	return 0;
}

sub any_change {
	my ($version) = @_;
	my @previous_files = (glob ".legit/version.$version/*");
	my @index_files = (glob ".legit/index/*");
	return 1 if (@previous_files != @index_files);
	foreach my $file (glob ".legit/index/*") {
		my $filename = $file;
		$filename =~ s/.*\///g;
		return 1 if (! -e ".legit/version.$version/$filename");
		return 1 if (compare("$file", ".legit/version.$version/$filename") == 1);
	}
	return 0;
}

1;
