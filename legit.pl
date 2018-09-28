#!/usr/bin/perl -w

use strict;
use warnings;
use detect_change;
use in_directory;
use File::Copy;
use File::Path;

#die "Usage: legit.pl <command> [<args>]\n" if (@ARGV == 0);

if (@ARGV == 0) {
	print <<eof;;
Usage: legit.pl <command> [<args>]

These are the legit commands:
   init       Create an empty legit repository
   add        Add file contents to the index
   commit     Record changes to the repository
   log        Show commit log
   show       Show file at particular state
   rm         Remove files from the current directory and from the index
   status     Show the status of files in the current directory, index, and repository
   branch     List, create or delete a branch
   checkout   Switch branches or restore current directory files
   merge      Join two development histories together
eof
die "\n";
}

my $command = shift @ARGV;
my @possible_command = ('init', 'add', 'commit', 'log', 'show', 'rm', 'status', 'branch', 'checkout', 'merge');
die "legit.pl: error: unknown command $command\nUsage: legit.pl <command> [<args>]\n" if (! grep(/^$command$/, @possible_command));

sub validate {
	die "legit.pl: error: no .legit directory containing legit repository exists\n" if (! -d -e ".legit");
}

sub current_version {
	my $version_nb = 0;
	my $dir = ".legit/version.$version_nb";
	while (-e $dir)	{
		$version_nb++;
		$dir = ".legit/version.$version_nb";
	}
	return $version_nb;
}
my $version_nb = current_version;

sub add {
	foreach my $file (@_) {
		#my $filename = $file;
		$file =~ s/.*\///g;
		my $path = ".legit/index/$file";
		die "legit.pl: error: can not open '$file'\n" if (! -e $file && ! -e $path);
		if (! -e $file && -e $path) {
			unlink "$path";
			next;
		}
		# need to detect change beforehand later
		next if (! diff_in_index($file));
		copy("$file", "$path") or die "Copy failed: $!";
	}
}

sub first_line {
    my ($file) = @_;
    open my $fh, '<', $file or die "Cannot open: $file $!";
    my $line = <$fh>;
    close $fh;
    return $line;
}

if ($command eq "init") {
	die "usage: legit.pl init\n" if (@ARGV != 0);
	if (! -d -e ".legit"){
		mkdir ".legit";
		mkdir ".legit/branch";
		#mkdir ".legit/index";
		open F, '>', '.legit/branch_hierarchy' or die "$!";
		print F "0 master";
		close F;
		open F, '>'. ".legit/current_branch";
		print F "master";
		close F;
		print "Initialized empty legit repository in .legit\n";
		exit 0;
	} else {
		die "legit.pl: error: .legit already exists\n";
	}	
}

validate;
open my $fh, '<', ".legit/current_branch" or die "Failed to fetch current branch $!";
my $current_branch = <$fh>;
close $fh;

if ($command eq "add") {
	mkdir ".legit/index" if (! -e ".legit/index");
	add(@ARGV);
	exit 0;
}

die "usage: legit.pl commit [-a] -m commit-message\n" if ($command eq "commit" && !(@ARGV == 2 || @ARGV == 3));

die "usage: legit.pl commit [-a] -m commit-message\n" if ($command eq "commit" && @ARGV == 2 && !($ARGV[0] eq '-m'));

die "usage: legit.pl commit [-a] -m commit-message\n" if ($command eq "commit" && @ARGV == 3 && !($ARGV[0] eq '-a' && $ARGV[1] eq '-m'));

#if ($command eq "commit" && $ARGV[0] eq "-m") {
if ($command eq "commit") {
	#die "usage: legit.pl commit [-a] -m commit-message\n" if (@ARGV != 2);
	die "nothing to commit\n" if (! -e '.legit/index/');
	add(glob ".legit/index/*") if (@ARGV == 3 && $ARGV[0] eq "-a" && $ARGV[1] eq "-m");
	if ($version_nb > 0) {
		die "nothing to commit\n" if (! any_change($version_nb - 1));
	}
	my $dir = ".legit/version.$version_nb";
	mkdir $dir;
	my $message = pop @ARGV;
	foreach my $file (glob ".legit/index/*") {
		my $filename = $file;
		$file =~ s/.*\///g;
		my $path = "$dir/$file";
		copy("$filename", "$path") or die "Copy Failed: $!";
	}
	print "Committed as commit $version_nb\n";
	my $record = ".legit/last_commit";
	my $log_file = ".legit/log";
	if ($current_branch ne 'master') {
	    $log_file = ".legit/branch/$current_branch/log";
	    $record = ".legit/branch/$current_branch/last_commit";
	}
	open F, '>', "$record" or die "$!";
	print F $version_nb;
	close F;
	open F, '>>', "$log_file" or die "legit.pl: error: can not open log\n";
	print F "$version_nb $message\n";
	close F;
	exit 0;
}

die "legit.pl: error: your repository does not have any commits yet\n" if (! -e ".legit/version.0");

if ($command eq "log") {
	#validate;
	#die "legit.pl: error: your repository does not have any commits yet\n" if (! -e ".legit/version.0");
	die "usage: legit.pl log\n" if (@ARGV != 0);
	my $log_file = ".legit/log";
	if ($current_branch ne 'master') {
	    my $log_file = ".legit/branch/$current_branch/log"
	}
	open F, '<', "$log_file" or die "legit.pl: error: can not open log\n";
	my @commits = <F>;
	close F;
	foreach my $commit (reverse @commits) {
		print $commit;
	}
	exit 0;
}

if ($command eq "show") {
	#validate;
	#die "legit.pl: error: your repository does not have any commits yet\n" if (! -e ".legit/version.0");
	die "usage: legit.pl <commit>:<filename>\n" if (@ARGV != 1);
	my $var = shift @ARGV;
	my @arr = split ':', $var;
	my $version = shift @arr;
	my $file = join ':', @arr;
	die "legit.pl: error: invalid filename '$file'\n" if ($file =~ /:/);
	if ($version ne '') {
		die "legit.pl: error: unknown commit '$version'\n" if ($version >= $version_nb);
		open F, '<', ".legit/version.$version/$file" or die "legit.pl: error: '$file' not found in commit $version\n";
		foreach my $line (<F>) {
			print $line;
		}
		close F;
	} else {
		open F, '<', ".legit/index/$file" or die "legit.pl: error: '$file' not found in index\n";
		foreach my $line (<F>) {
			print $line;
		}
		close F;
	}
	exit 0;
}

#die "legit.pl: error: your repository does not have any commits yet\n" if ($command eq "rm" && ! -e ".legit/version.0");

die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && @ARGV == 0);

die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && ($ARGV[0] =~ /^--/) && !($ARGV[0] eq '--cached' || $ARGV[0] eq '--force'));

die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && @ARGV > 1 && ($ARGV[0] =~ /^--/) && ($ARGV[1] =~ /^--/) && !($ARGV[1] eq '--cached' || $ARGV[1] eq '--force'));

#die "legit.pl: error: your repository does not have any commits yet\n" if ($command eq "branch" && ! -e ".legit/version.0");
#die "legit.pl: error: your repository does not have any commits yet\n" if ($command eq "checkout" && ! -e ".legit/version.0");
die "usage: legit.pl branch [-d] <branch>\n" if ($command eq "branch" && @ARGV > 2);
die "usage: legit.pl branch [-d] <branch>\n" if ($command eq "branch" && @ARGV == 2 && $ARGV[0] ne "-d");
die "usage: legit.pl checkout <branch>\n" if ($command eq "checkout" && @ARGV != 1);

my $origin_file = ".legit/last_commit";
$origin_file = ".legit/branch/$current_branch/last_commit" if ($current_branch ne 'master');
#open $fh, '<', "$origin_file" or die "Cannot open '$origin_file' $!";
#my $current = <$fh>;
#close $fh;
my $current = first_line("$origin_file");
#print "current version: $current\n";

if ($command eq "rm") {
    if ($#ARGV >= 2) {
        foreach my $i (2..$#ARGV) {
            die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($ARGV[$i] =~ /^--/);
        }
    }
    my $rm_method;
    $rm_method = "both" if ($ARGV[0] =~ /^[^-]/);
	$rm_method = "index" if ($ARGV[0] eq "--cached" && $ARGV[1] ne "--force");
    $rm_method = "force_both" if ($ARGV[0] eq "--force" && $ARGV[1] ne "--cached");
    $rm_method = "force_index" if ($ARGV[0] eq "--force" && $ARGV[1] eq "--cached");
    $rm_method = "force_index" if ($ARGV[0] eq "--cached" && $ARGV[1] eq "--force");
    if ($rm_method eq "index") {
	    shift @ARGV;
        #my $current = $version_nb - 1;
        #my @index_files = glob ".legit/index/*";
	    foreach my $file (@ARGV) {
		    die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
		    die "legit.pl: error: '$file' in index is different to both working file and repository\n" if (dir_n_index($file) && index_n_repo($file, $current));
		    #unlink ".legit/index/$file";
        }
        foreach my $file (@ARGV) {
		    unlink ".legit/index/$file";
        }
    } elsif ($rm_method eq "both") {
        #my @index_files = glob ".legit/index/*";
	    foreach my $file (@ARGV) {		
		    #my $current = $version_nb - 1;
		    #my @last_commit = glob ".legit/version.$current/*";
		    die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
		    die "legit.pl: error: '$file' has changes staged in the index\n" if (in_index($file) && !in_repo($file, $current));
		    die "legit.pl: error: '$file' has changes staged in the index\n" if (!dir_n_index($file) && index_n_repo($file, $current));
		    die "legit.pl: error: '$file' in index is different to both working file and repository\n" if (dir_n_index($file) && index_n_repo($file, $current));
		    die "legit.pl: error: '$file' in repository is different to working file\n" if (dir_n_index($file) && !index_n_repo($file, $current));
		    #unlink "$file" if (-e "./$file");
		    #unlink ".legit/index/$file" if (-e ".legit/index/$file");
	    }
        foreach my $file (@ARGV) {
		    unlink "$file" if (-e "./$file");
		    unlink ".legit/index/$file" if (-e ".legit/index/$file");
        }
    } elsif ($rm_method eq "force_both") {
        #my @index_files = glob ".legit/index/*";
        shift @ARGV;
        foreach my $file (@ARGV) {
            die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
            #unlink "$file" if (-e "./$file");
		    #unlink ".legit/index/$file" if (-e ".legit/index/$file");
        }
        foreach my $file (@ARGV) {
		    unlink "$file" if (-e "./$file");
		    unlink ".legit/index/$file" if (-e ".legit/index/$file");
        }
    } elsif ($rm_method eq "force_index") {
        #my @index_files = glob ".legit/index/*";
        shift @ARGV;
        shift @ARGV;
        foreach my $file (@ARGV) {
            die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
            #unlink ".legit/index/$file" if (-e ".legit/index/$file");
        }
        foreach my $file (@ARGV) {
		    unlink ".legit/index/$file";
        }
    }
    exit 0;
}

if ($command eq "status") {
    die "legit.pl: error: your repository does not have any commits yet\n" if (! -e ".legit/version.0");
    my @current_dir = glob "*";
    #my @index_files = glob ".legit/index/*";
    #my $current = $version_nb - 1;
    my @last_commit = glob ".legit/version.$current/*";
    while (@last_commit) {
        last if (!($last_commit[0] =~ /.*\//));
        my $file = shift @last_commit;
        $file =~ s/.*\///g;
        push @last_commit, $file;
    }
    my @files = (@current_dir, @last_commit);
    my %seen = ();
    @files = grep { ! $seen{$_}++ } @files ;
    @files = sort {$a cmp $b} @files;
    foreach my $file (@files) {
        print "$file - ";
        #if (grep(/\/$file$/, @index_files) && !grep(/$file$/, @last_commit)) {
        if (in_index($file) && !in_repo($file, $current)) {
            print "added to index\n";
            next;
        }
        #if (!grep(/$file$/, @current_dir) && grep(/\/$file$/, @index_files)) {
        if (!in_current($file) && in_index($file)) {
            print "file deleted\n";
            next;
        }
        #if (grep(/$file$/, @current_dir) && !grep(/\/$file$/, @index_files)) {
        if (in_current($file) && !in_index($file)) {
            print "untracked\n";
            next;
        }
        #if (!grep(/$file$/, @current_dir) && !grep(/\/$file$/, @index_files)) {
        if (!in_current($file) && !in_index($file)) {
            print "deleted\n";
            next;
        }        
        if (same_as_repo($file, $current)) {
            print "same as repo\n";
            next;
        }
        print "file changed, different changes staged for commit\n" if (dir_n_index($file) && index_n_repo($file, $current));
        print "file changed, changes staged for commit\n" if (!dir_n_index($file) && index_n_repo($file, $current));
        print "file changed, changes not staged for commit\n" if  (dir_n_index($file) && !index_n_repo($file, $current));
        #print "same as repo\n" if (!dir_n_index($file) && !index_n_repo($file, $current));
        
    }
    exit 0;
}



if($command eq "branch") {
    if (@ARGV == 0) {
        #die "legit.pl: error: branch 'master' already exists\n" if ($ARGV[0] eq "master");
        if (-e ".legit/branch_list") {
            open my $fh, '<', ".legit/branch_list" or die "$!";
            foreach my $line (<$fh>) {
                print "$line";
            }
            close $fh; 
        }
        print "master\n";
    }
    if (@ARGV == 1) {
        die "legit.pl: error: branch 'master' already exists\n" if ($ARGV[0] eq "master");
        if (-e ".legit/branch_list") {
            open my $fh, '<', ".legit/branch_list" or die "$!";
            foreach my $line (<$fh>) {
                chomp $line;
                die "legit.pl: error: branch '$line' already exists\n" if ($line eq $ARGV[0]);
            }
            close $fh; 
        }
        
        mkdir ".legit/branch/$ARGV[0]";
        open F, ">", ".legit/branch/$ARGV[0]/originate_version" or die "$!";
        print F $current;
        close F;
        open F, ">", ".legit/branch/$ARGV[0]/last_commit" or die "$!";
        print F $current;
        close F;
        copy(".legit/log", ".legit/branch/$ARGV[0]/log") or die "Copy failed: $!";
        open $fh, ">>", ".legit/branch_list" or die "$!";
        print $fh "$ARGV[0]\n";
        close $fh;
    }
    if (@ARGV == 2) {
        die "legit.pl: error: can not delete branch 'master'\n" if ($ARGV[1] eq 'master');
        die "legit.pl: error: branch '$ARGV[1]' does not exist\n" if(!-e ".legit/branch_list");
        die "legit.pl: error: can not delete branch '$ARGV[1]'\n" if ($ARGV[1] eq $current_branch);
        open FILE, '<', ".legit/branch_list" or die "$!";
        my @branches = <FILE>;
        close FILE;
        die "legit.pl: error: branch '$ARGV[1]' does not exist\n" if (! grep(/^$ARGV[1]$/, @branches));
        my $origin_file = ".legit/branch/$ARGV[1]/originate_version";
        my $last_file = ".legit/branch/$ARGV[1]/last_commit";
        my $originate = first_line($origin_file);
        my $current_ = first_line($last_file);
        die "legit.pl: error: branch '$ARGV[1]' has unmerged changes\n" if ($originate < $current_);
        open FILE, '>', ".legit/branch_list" or die "$!";
        for my $branch (@branches) {
            print FILE $branch unless($branch =~ m/$ARGV[1]/);
        }
        close FILE;
        rmtree ".legit/branch/$ARGV[1]" or die "Cannot delete $!";
        print "Deleted branch '$ARGV[1]'\n";
    }
    exit 0;
}

if ($command eq "checkout") {
    #open my $fh, '<', ".legit/current_branch" or die "$!";
    #my $current_branch = <$fh>;
    #close $fh;
    my $future_branch = $ARGV[0];
    die "Already on '$current_branch'\n" if ($future_branch eq $current_branch);
    die "legit.pl: error: unknown branch '$future_branch'\n" if(!-e ".legit/branch_list");
    open FILE, '<', ".legit/branch_list" or die "$!";
    my @branches = <FILE>;
    close FILE;
    if ($future_branch ne 'master') {
        die "legit.pl: error: unknown branch '$future_branch'\n" if (!grep(/^$future_branch$/, @branches));
    }
    #for my $branch (@branches) {
    #    die "legit.pl: error: unknown branch '$ARGV[0]'\n" if ($ARGV[0] eq $branch);
    #}
    my $current_file = ".legit/last_commit";
    $current_file = ".legit/branch/$current_branch/last_commit" if ($current_branch ne 'master');
    my $future_file = ".legit/last_commit";
    $future_file = ".legit/branch/$future_branch/last_commit" if ($future_branch ne 'master');
    my $current_version = first_line($current_file);
    my $future_version = first_line($future_file);
    #print "$current_version $future_version \n";
    my @current_repo = glob ".legit/version.$current_version/*";
    my @future_repo = glob ".legit/version.$future_version/*";
    my @overwritten;
    foreach my $file (@future_repo) {
        my $filename = $file;
        $filename =~ s/.*\///g;
        if (grep(/^\.\/$filename$/, glob "./*") && !same_as_repo($filename, $current_version) && $current_version != $future_version) {
            push @overwritten, $filename;
        }
    }
    if (@overwritten > 0) {
        print "legit.pl: error: Your changes to the following files would be overwritten by checkout:\n";
        foreach my $file (sort { $a cmp $b } @overwritten) {
            print "$file\n";
        }
        exit 0;
    }
    foreach my $file (@current_repo) {
        $file =~ s/.*\///g;
        unlink $file if (-e $file && same_as_repo($file, $current_version));
    }
    foreach my $file (@future_repo) {
        my $filename = $file;
        $filename =~ s/.*\///g;
        copy($file, $filename) if (!-e $filename || same_as_repo($filename, $current_version));
    }
    #}
    open FILE, '>', ".legit/current_branch" or die "$!";
    print FILE $future_branch;
    close FILE;
    print "Switched to branch '$future_branch'\n";
    exit 0;
}

die "legit.pl: error: empty commit message\n" if ($command eq "merge" && @ARGV == 1);
die "usage: legit.pl merge <branch|commit> -m message\n" if ($command eq "merge" && @ARGV != 3);
die "usage: legit.pl merge <branch|commit> -m message\n" if ($command eq "merge" && !($ARGV[0] eq '-m' || $ARGV[1] eq '-m'));
my $mg_msg;
my $mg_branch;
if ($command eq "merge" && $ARGV[0] eq '-m') {
    $mg_msg = $ARGV[1];
    $mg_branch = $ARGV[2];
}
if ($command eq "merge" && $ARGV[1] eq '-m') {
    $mg_msg = $ARGV[2];
    $mg_branch = $ARGV[0];
}

if ($command eq "merge") {
    die "legit.pl: error: unknown branch '$mg_branch'\n" if ($mg_branch =~ /^\d+$/ && $mg_branch >= $version_nb);
    open FILE, '<', ".legit/branch_list" or die "$!";
    my @branches = <FILE>;
    close FILE;
    die "legit.pl: error: unknown branch '$mg_branch'\n" if (! grep(/^$mg_branch$/, @branches));
    my $current_file = ".legit/last_commit";
    $current_file = ".legit/branch/$current_branch/last_commit" if ($current_branch ne 'master');
    my $future_file = ".legit/last_commit";
    $future_file = ".legit/branch/$mg_branch/last_commit" if ($mg_branch ne 'master');
    my $current_version = first_line($current_file);
    my $future_version = first_line($future_file);
    if ($mg_branch ne 'master') {
        my $future_origin_file = ".legit/branch/$mg_branch/originate_version";
        my $future_origin = first_line($future_origin_file);
        die "Already up to date\n" if ($future_origin == $future_version && $current_version == $future_version);
        if ($current_version == $future_origin && $future_version > $current_version) {
            print "Fast-forward: no commit created\n";
            open my $fh, '>', ".legit/branch/$mg_branch/originate_version";
            print $fh $future_version;
            close $fh;
            open $fh, '>', ".legit/last_commit";
            print $fh $future_version;
            close $fh;
            my @bh_repo = glob ".legit/version.$future_version/*";
            foreach my $file (@bh_repo) {
                my $filename = $file;
                $filename =~ s/.*\///g;
                copy($file, "./$filename") or die "Copy failed $!";
            }
            open $fh, '<', ".legit/branch/$mg_branch/log";
            my @bh_log = <$fh>;
            close $fh;
            # need to be improved
            open $fh, '>>', ".legit/log";
            foreach my $line (@bh_log) {
                print $fh $line;
            }
            close $fh;
        }
    }
    if ($mg_branch eq 'master') {
        my $current_origin_file = ".legit/branch/$current_branch/originate_version";
        my $current_origin = first_line($current_origin_file);
        if ($current_origin == $current_version && $future_version > $current_version) {
            print "Fast-forward: no commit created\n";
            open my $fh, '>', ".legit/branch/$current_branch/originate_version";
            print $fh $future_version;
            close $fh;
            open $fh, '>', ".legit/branch/$current_branch/last_commit";
            print $fh $future_version;
            close $fh;
            my @master_repo = glob ".legit/version.$future_version/*";
            foreach my $file (@master_repo) {
                my $filename = $file;
                $filename =~ s/.*\///g;
                copy($file, "./$filename") or die "Copy failed $!";
            }
        }
    }
}

