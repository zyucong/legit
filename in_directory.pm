#!/usr/bin/perl -w

package in_directory;
use strict;
use warnings;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(in_current in_index in_repo);

sub in_current {
    my ($file) = @_;
    my @current_dir = glob "*";
    return 1 if (grep(/$file$/, @current_dir));
    return 0;
}

sub in_index {
    my ($file) = @_;
    my @index_files = glob ".legit/index/*";
    return 1 if (grep(/\/$file$/, @index_files));
    return 0;
}

sub in_repo {
    my ($file, $version) = @_;
    my @repo_files = glob ".legit/version.$version/*";
    return 1 if (grep(/\/$file$/, @repo_files));
    return 0;
}
