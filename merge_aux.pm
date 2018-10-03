#!/usr/bin/perl -w

package merge_aux;
use strict;
use warnings;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(update_log);
# to update the log file in current branch
sub update_log {
    my ($current_branch, $mg_branch) = @_;
    open FILE, '<', ".legit/branch/$current_branch/log" or die "$!";
    my @current_log = <FILE>;
    close FILE;
    open FILE, '<', ".legit/branch/$mg_branch/log" or die "$!";
    my @mg_log = <FILE>;
    close FILE;
    open FILE, '>', ".legit/branch/$current_branch/log" or die "$!";
    # combine the log file, the log file in current branch now contain the updated information
    while (@current_log != 0 && @mg_log != 0) {
        my $current_line = shift @current_log;
        my $mg_line = shift @mg_log;
        my @current_temp = split / /, $current_line;
        my @mg_temp = split / /, $mg_line;
        my $current_nb = $current_temp[0];
        my $mg_nb = $mg_temp[0];
        if ($current_nb == $mg_nb) {
            print FILE $current_line;
            next;
        }
        if ($current_nb < $mg_nb) {
            print FILE $current_line;
            unshift @mg_log, $mg_line;
            next;
        }
        if ($current_nb > $mg_nb) {
            print FILE $mg_line;
            unshift @current_log, $current_line;
            next;
        }
    }
    # no need to compare when one of the 2 arrays has nothing left
    while (@current_log != 0 && @mg_log == 0) {
        my $next_log = shift @current_log;
        print FILE $next_log;
    }
    while (@current_log == 0 && @mg_log != 0) {
        my $next_log = shift @mg_log;
        print FILE $next_log;
    }
    close FILE;
}

1;
