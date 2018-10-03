#!/usr/bin/perl -w

package in_directory;
use strict;
use warnings;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(in_current in_index in_repo);
# to check if a file is in working directory
sub in_current {
    my ($file) = @_;
    my @current_dir = glob "*";
    return 1 if (grep(/$file$/, @current_dir));
    return 0;
}
# to check if a file is in index directory
sub in_index {
    my ($file) = @_;
    my @index_files = glob ".legit/index/*";
    return 1 if (grep(/\/$file$/, @index_files));
    return 0;
}
# to check if a file is in latest repository of current branch
sub in_repo {
    my ($file, $version) = @_;
    my @repo_files = glob ".legit/version.$version/*";
    return 1 if (grep(/\/$file$/, @repo_files));
    return 0;
}
