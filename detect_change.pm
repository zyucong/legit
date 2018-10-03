#!/usr/bin/perl -w

package detect_change;
use strict;
use warnings;
use File::Compare;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(any_change index_n_repo dir_n_index diff_in_index same_as_repo);
# return 1 if the file in working directory is the same as the one in repo
# return 0 otherwise
sub same_as_repo {
    my ($file, $version) = @_;
	my $file_in_repo = ".legit/version.$version/$file";
	return 1 if (compare("$file", "$file_in_repo") == 0);
	return 0;
}
# return 1 if the file in index directory is different with the one in repo
# return 0 otherwise
sub index_n_repo {
	my ($file, $version) = @_;
	my $filename = ".legit/index/$file";
	my $file_in_repo = ".legit/version.$version/$file";
	return 1 if (compare("$filename", "$file_in_repo"));
	return 0;
}
# return 1 if the file in working directory is different with the one in index
# return 0 otherwise
sub dir_n_index {
	my ($file) = @_;
	my $filename = "./$file";
	my $file_in_index = ".legit/index/$file";
	#return 1 if (! -e $file_in_index);
	return 1 if (compare("$filename", "$file_in_index") == 1);
	return 0;
}
# the only difference between this and above function is that also return 1 if the file in index does not exist
sub diff_in_index {
	my ($file) = @_;
	my $filename = "./$file";
	my $file_in_index = ".legit/index/$file";
	return 1 if (! -e $file_in_index);
	return 1 if (compare("$filename", "$file_in_index") == 1);
	return 0;
}

# detect if any file has change in index directory and in latest repository
# mainly to decide if it is needed to commit
sub any_change {
	my ($version) = @_;
	my @previous_files = (glob ".legit/version.$version/*");
	my @index_files = (glob ".legit/index/*");
	# return 1 if the number of files is different between 2 diretories
	return 1 if (@previous_files != @index_files);
	foreach my $file (glob ".legit/index/*") {
		my $filename = $file;
		$filename =~ s/.*\///g;
		# if the number of files are same, if a file exists in one directory but not exists in the other, return 1
		return 1 if (! -e ".legit/version.$version/$filename");
		# if a file both appear in index and in repo, compare their difference
		return 1 if (compare("$file", ".legit/version.$version/$filename") == 1);
	}
	return 0;
}

1;
