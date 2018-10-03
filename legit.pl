#!/usr/bin/perl -w

use strict;
use warnings;
## check if there is change between files with same name in different directory
use detect_change;  # qw(any_change index_n_repo dir_n_index diff_in_index same_as_repo)
## check if a file is in specified directory, used mainly in rm and status
use in_directory;   # qw(in_current in_index in_repo)   
## to update the log file in current branch
use merge_aux;      # qw(update_log)  
use File::Copy;
use File::Path;
use File::Compare qw(compare compare_text);
use Algorithm::Merge qw(merge diff3 traverse_sequences3);

# error message on how to use legit
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

# from now on, @ARGV consists of solely parameter(s) for the command
my $command = shift @ARGV;
my @possible_command = ('init', 'add', 'commit', 'log', 'show', 'rm', 'status', 'branch', 'checkout', 'merge');
# print error message for illegal command
die "legit.pl: error: unknown command $command\nUsage: legit.pl <command> [<args>]\n" if (! grep(/^$command$/, @possible_command));

# subroutine used for any legal command other than init
sub validate {
    die "legit.pl: error: no .legit directory containing legit repository exists\n" if (! -d -e ".legit");
}

# get the version number for next committed repo
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

# add files from current directory to index, used in add and commit -a
sub add {
    foreach my $file (@_) {
        $file =~ s/.*\///g;
        my $path = ".legit/index/$file";
        die "legit.pl: error: can not open '$file'\n" if (! -e $file && ! -e $path);
        # delete any file that is not existed in current directory
        if (! -e $file && -e $path) {
            unlink "$path";
            next;
        }
        # skip this file if it is the same in index 
        next if (! diff_in_index($file));
        copy("$file", "$path") or die "Copy failed: $!";
    }
}

# used in subset2, to read the first line of a file
sub first_line {
    my ($file) = @_;
    open my $fh, '<', $file or die "Cannot open: $file $!";
    my $line = <$fh>;
    close $fh;
    return $line;
}

# used to read the file and return the content as an array, mainly used in subset2
sub read_file {
    my ($file) = @_;
    open my $fh, '<', $file or die "Cannot open: $file $!";
    my @contents = <$fh>;
    close $fh;
    return @contents;
}

if ($command eq "init") {
    die "usage: legit.pl init\n" if (@ARGV != 0);
    if (! -d -e ".legit"){
        mkdir ".legit";
        mkdir ".legit/branch";
        mkdir ".legit/branch/master";
        open F, '>', ".legit/branch/master/originate_version" or die "$!";
        print F '0';
        close F;
        open F, '>', ".legit/branch_list" or die "$!";
        print F "master\n";
        close F;
        open F, '>', ".legit/current_branch";
        print F "master";
        close F;
        print "Initialized empty legit repository in .legit\n";
        exit 0;
    } else {
        die "legit.pl: error: .legit already exists\n";
    }
}
# report error for any command except init when .legit doesn't exist
validate;
my $current_branch = first_line(".legit/current_branch");

if ($command eq "add") {
    mkdir ".legit/index" if (! -e ".legit/index");
    add(@ARGV);
    exit 0;
}

# detect all possible illegal parameters for commit
die "usage: legit.pl commit [-a] -m commit-message\n" if ($command eq "commit" && !(@ARGV == 2 || @ARGV == 3));
die "usage: legit.pl commit [-a] -m commit-message\n" if ($command eq "commit" && @ARGV == 2 && !($ARGV[0] eq '-m'));
die "usage: legit.pl commit [-a] -m commit-message\n" if ($command eq "commit" && @ARGV == 3 && !($ARGV[0] eq '-a' && $ARGV[1] eq '-m'));

if ($command eq "commit") {
    die "nothing to commit\n" if (! -e '.legit/index/');
    # only additional command for commit -a
    add(glob ".legit/index/*") if (@ARGV == 3 && $ARGV[0] eq "-a" && $ARGV[1] eq "-m");
    if ($version_nb > 0) {
        # import from detect_change.pm, print error message if files in index are the same as previous repo
        my $previous_version = first_line(".legit/branch/$current_branch/last_commit");
        die "nothing to commit\n" if (! any_change($previous_version));
    }
    my $dir = ".legit/version.$version_nb";
    mkdir $dir;
    my $message = pop @ARGV;
    # copy all the files from index to the new repo directory, yeah I don't have time for challenge
    foreach my $file (glob ".legit/index/*") {
        my $filename = $file;
        $file =~ s/.*\///g;
        my $path = "$dir/$file";
        copy("$filename", "$path") or die "Copy Failed: $!";
    }
    print "Committed as commit $version_nb\n";
    # update log file and the last commit number accordingly
    my $log_file = ".legit/branch/$current_branch/log";
    my $record = ".legit/branch/$current_branch/last_commit";
    open F, '>', "$record" or die "$!";
    print F $version_nb;
    close F;
    open F, '>>', "$log_file" or die "legit.pl: error: can not open log\n";
    print F "$version_nb $message\n";
    close F;
    exit 0;
}

# all the following command should detect this situation.
die "legit.pl: error: your repository does not have any commits yet\n" if (! -e ".legit/version.0");
if ($command eq "log") {
    die "usage: legit.pl log\n" if (@ARGV != 0);
    my $log_file = ".legit/branch/$current_branch/log";
    open F, '<', "$log_file" or die "legit.pl: error: can not open log\n";
    my @commits = <F>;
    close F;
    # store in ascending order, print out in reversed order
    foreach my $commit (reverse @commits) {
        print $commit;
    }
    exit 0;
}

if ($command eq "show") {
    die "usage: legit.pl <commit>:<filename>\n" if (@ARGV != 1);
    my $var = shift @ARGV;
    my @arr = split ':', $var;
    my $version = shift @arr;
    my $file = join ':', @arr;
    # detect anomalies when more than 1 colon appear in the parameter
    die "legit.pl: error: invalid filename '$file'\n" if ($file =~ /:/);
    if ($version ne '') {
        die "legit.pl: error: unknown commit '$version'\n" if ($version >= $version_nb);
        open F, '<', ".legit/version.$version/$file" or die "legit.pl: error: '$file' not found in commit $version\n";
        foreach my $line (<F>) {
            print $line;
        }
        close F;
    } else {
        # If the commit number is omitted the contents of the file in the index should be printed
        open F, '<', ".legit/index/$file" or die "legit.pl: error: '$file' not found in index\n";
        foreach my $line (<F>) {
            print $line;
        }
        close F;
    }
    exit 0;
}

# detect all possible illegal parameters for rm
die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && @ARGV == 0);
die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && ($ARGV[0] =~ /^--/) && !($ARGV[0] eq '--cached' || $ARGV[0] eq '--force'));
die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && @ARGV > 1 && ($ARGV[0] =~ /^--/) && ($ARGV[1] =~ /^--/) && !($ARGV[1] eq '--cached' || $ARGV[1] eq '--force'));

# detect all possible illegal parameters for branch and checkout
die "usage: legit.pl branch [-d] <branch>\n" if ($command eq "branch" && @ARGV > 2);
die "usage: legit.pl branch [-d] <branch>\n" if ($command eq "branch" && @ARGV == 2 && $ARGV[0] ne "-d");
die "usage: legit.pl checkout <branch>\n" if ($command eq "checkout" && @ARGV != 1);

# retrieve the version number of this branch
my $origin_file = ".legit/branch/$current_branch/last_commit";
my $current = first_line("$origin_file");

if ($command eq "rm") {
    # detect illegal filename
    if ($#ARGV >= 2) {
        foreach my $i (2..$#ARGV) {
            die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($ARGV[$i] =~ /^--/);
        }
    }
    # set a flag for 4 different rm methods
    my $rm_method;
    $rm_method = "both" if ($ARGV[0] =~ /^[^-]/);
	$rm_method = "index" if ($ARGV[0] eq "--cached" && $ARGV[1] ne "--force");
    $rm_method = "force_both" if ($ARGV[0] eq "--force" && $ARGV[1] ne "--cached");
    $rm_method = "force_index" if ($ARGV[0] eq "--force" && $ARGV[1] eq "--cached");
    $rm_method = "force_index" if ($ARGV[0] eq "--cached" && $ARGV[1] eq "--force");
    if ($rm_method eq "index") {
        # discard parameter "--cached"
	    shift @ARGV;
	    # validate the files
	    foreach my $file (@ARGV) {
	        # die when a file is not in index
		    die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
		    # die when a file in index is different to or not exists in working directory or in repo
		    die "legit.pl: error: '$file' in index is different to both working file and repository\n" if (dir_n_index($file) && index_n_repo($file, $current));
        }
        # any file above goes wrong, the whole delete excution should not go ahead.
        foreach my $file (@ARGV) {
	        unlink ".legit/index/$file";
        }
    } elsif ($rm_method eq "both") {
        # validate the files
	    foreach my $file (@ARGV) {		
            die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
            die "legit.pl: error: '$file' has changes staged in the index\n" if (in_index($file) && !in_repo($file, $current));
            die "legit.pl: error: '$file' has changes staged in the index\n" if (!dir_n_index($file) && index_n_repo($file, $current));
            die "legit.pl: error: '$file' in index is different to both working file and repository\n" if (dir_n_index($file) && index_n_repo($file, $current));
            die "legit.pl: error: '$file' in repository is different to working file\n" if (dir_n_index($file) && !index_n_repo($file, $current));
        }
        # Delete iff all the files above are valid to be deleted
        foreach my $file (@ARGV) {
            unlink "$file" if (-e "./$file");
            unlink ".legit/index/$file" if (-e ".legit/index/$file");
        }
    } elsif ($rm_method eq "force_both") {
        # discard parameter "--force"
        shift @ARGV;
        foreach my $file (@ARGV) {
            # die if any of the files not in index
            die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
        }
        foreach my $file (@ARGV) {
            unlink "$file" if (-e "./$file");
            unlink ".legit/index/$file" if (-e ".legit/index/$file");
        }
    } elsif ($rm_method eq "force_index") {
        # discard parameter "--force" and "--cached"
        shift @ARGV;
        shift @ARGV;
        foreach my $file (@ARGV) {
            die "legit.pl: error: '$file' is not in the legit repository\n" if (!in_index($file));
        }
        foreach my $file (@ARGV) {
            unlink ".legit/index/$file";
        }
    }
    exit 0;
}

if ($command eq "status") {
    # note that the status of files in current directory and latest version repo shoule be listed
    my @current_dir = glob "*";
    my @last_commit = glob ".legit/version.$current/*";
    # update array @last_commit to remove the path, only keep the file names
    while (@last_commit) {
        last if (!($last_commit[0] =~ /.*\//));
        my $file = shift @last_commit;
        $file =~ s/.*\///g;
        push @last_commit, $file;
    }
    my @files = (@current_dir, @last_commit);
    my %seen = ();
    # elimate duplicate files in @files
    @files = grep { ! $seen{$_}++ } @files ;
    @files = sort {$a cmp $b} @files;
    foreach my $file (@files) {
        print "$file - ";
        # if a file is in index but not in latest version repository
        if (in_index($file) && !in_repo($file, $current)) {
            print "added to index\n";
            next;
        }
        # if a file is not in current directory but in the index
        if (!in_current($file) && in_index($file)) {
            print "file deleted\n";
            next;
        }
        # if a file is in current directory but not in index
        if (in_current($file) && !in_index($file)) {
            print "untracked\n";
            next;
        }
        # if a file is neither in current directory nor in index
        if (!in_current($file) && !in_index($file)) {
            print "deleted\n";
            next;
        }
        # all the other situations below have relevant files in index
        # if a file in current directory is the same as the one in latest version repository
        if (same_as_repo($file, $current)) {
            print "same as repo\n";
            next;
        }
        # situation below wouldn't duplicate
        print "file changed, different changes staged for commit\n" if (dir_n_index($file) && index_n_repo($file, $current));
        print "file changed, changes staged for commit\n" if (!dir_n_index($file) && index_n_repo($file, $current));
        print "file changed, changes not staged for commit\n" if  (dir_n_index($file) && !index_n_repo($file, $current));
    }
    exit 0;
}


if($command eq "branch") {
    # display branch list
    if (@ARGV == 0) {
        open my $fh, '<', ".legit/branch_list" or die "$!";
        my @branch_list = <$fh>;
        close $fh; 
        foreach my $line (sort {$a cmp $b} @branch_list) {
            print "$line";
        }
    }
    if (@ARGV == 1) {
        #die "legit.pl: error: branch 'master' already exists\n" if ($ARGV[0] eq "master");
        if (-e ".legit/branch_list") {
            open my $fh, '<', ".legit/branch_list" or die "$!";
            foreach my $line (<$fh>) {
                chomp $line;
                die "legit.pl: error: branch '$line' already exists\n" if ($line eq $ARGV[0]);
            }
            close $fh; 
        }
        # initialize all necessary files needed for a new branch
        mkdir ".legit/branch/$ARGV[0]";
        open F, ">", ".legit/branch/$ARGV[0]/originate_version" or die "$!";
        print F $current;
        close F;
        open F, ">", ".legit/branch/$ARGV[0]/last_commit" or die "$!";
        print F $current;
        close F;
        # copy log files from base stage to the new branch
        copy(".legit/branch/$current_branch/log", ".legit/branch/$ARGV[0]/log") or die "Copy failed: $!";
        open my $fh, ">>", ".legit/branch_list" or die "$!";
        print $fh "$ARGV[0]\n";
        close $fh;
    }
    # delete branch
    if (@ARGV == 2) {
        die "legit.pl: error: can not delete branch 'master'\n" if ($ARGV[1] eq 'master');
        die "legit.pl: error: branch '$ARGV[1]' does not exist\n" if(!-e ".legit/branch_list");
        die "legit.pl: error: can not delete branch '$ARGV[1]'\n" if ($ARGV[1] eq $current_branch);
        my @branches = read_file(".legit/branch_list");
        die "legit.pl: error: branch '$ARGV[1]' does not exist\n" if (! grep(/^$ARGV[1]$/, @branches));
        my $origin_file = ".legit/branch/$ARGV[1]/originate_version";
        my $last_file = ".legit/branch/$ARGV[1]/last_commit";
        my $originate = first_line("$origin_file");
        my $current_ = first_line("$last_file");
        if ($originate < $current_) {
            my $merge_version_file = ".legit/branch/$ARGV[1]/merge_version";
            my $merge_version = first_line("$merge_version_file") if (-e "$merge_version_file");
            my $current_version = first_line(".legit/branch/$current_branch/last_commit");
            die "legit.pl: error: branch '$ARGV[1]' has unmerged changes\n" unless (-e $merge_version_file && $merge_version == $current_version);
        }
        open FILE, '>', ".legit/branch_list" or die "$!";
        # update branch list to remove the deleted one
        for my $branch (@branches) {
            print FILE $branch unless($branch =~ m/$ARGV[1]/);
        }
        close FILE;
        # remove the relevant directory
        rmtree ".legit/branch/$ARGV[1]" or die "Cannot delete $!";
        print "Deleted branch '$ARGV[1]'\n";
    }
    exit 0;
}

if ($command eq "checkout") {
    my $future_branch = $ARGV[0];
    die "Already on '$current_branch'\n" if ($future_branch eq $current_branch);
    die "legit.pl: error: unknown branch '$future_branch'\n" if(!-e ".legit/branch_list");
    my @branches = read_file(".legit/branch_list");
    die "legit.pl: error: unknown branch '$future_branch'\n" if (!grep(/^$future_branch$/, @branches));
    my $current_file = ".legit/branch/$current_branch/last_commit";
    my $future_file = ".legit/branch/$future_branch/last_commit";
    my $current_version = first_line($current_file);
    my $future_version = first_line($future_file);
    my @current_repo = glob ".legit/version.$current_version/*";
    my @future_repo = glob ".legit/version.$future_version/*";
    my @overwritten;
    foreach my $file (@future_repo) {
        my $filename = $file;
        $filename =~ s/.*\///g;
        # a file would be overwritten when checkout to anthoer branch is that the future branch has a file in the same name
        # and the file hasn't been backed up && the current branch and the future branch is not in same version number. 
        if (grep(/^\.\/$filename$/, glob "./*") && !same_as_repo($filename, $current_version) && $current_version != $future_version) {
            push @overwritten, $filename;
        }
        # also trigger overwritten warning when a file is identical to the one in repo but has difference with the one in index
        if (grep(/^\.\/$filename$/, glob "./*") && diff_in_index($filename) && same_as_repo($filename, $current_version) && $current_version != $future_version) {
            push @overwritten, $filename;
        }
    }
    foreach my $file (@current_repo) {
        my $filename = $file;
        $filename =~ s/.*\///g;
        # a file would be overwritten when checkout to anthoer branch is that the future branch has a file in the same name
        # and the file hasn't been backed up && the current branch and the future branch is not in same version number. 
        if (grep(/^\.\/$filename$/, glob "./*") && !same_as_repo($filename, $current_version) && $current_version != $future_version) {
            push @overwritten, $filename if (!grep(/^$filename$/, @overwritten));
        }
        # also trigger overwritten warning when a file is identical to the one in repo but has difference with the one in index
        if (grep(/^\.\/$filename$/, glob "./*") && diff_in_index($filename) && same_as_repo($filename, $current_version) && $current_version != $future_version) {
            push @overwritten, $filename if (!grep(/^$filename$/, @overwritten));
        }
    }
    # All the files that trigger the overwritten warning should be printed out.
    if (@overwritten > 0) {
        print "legit.pl: error: Your changes to the following files would be overwritten by checkout:\n";
        foreach my $file (sort { $a cmp $b } @overwritten) {
            print "$file\n";
        }
        exit 1;
    }
    # delete all the files in current directory and index that is same as those in repository
    if ($current_version != $future_version) {
        foreach my $file (@current_repo) {
            $file =~ s/.*\///g;
            my $index_file = ".legit/index/$file";
            if (same_as_repo($file, $current_version)) {
                unlink $file;
                unlink $index_file;
            }
        }
        foreach my $file (@future_repo) {
            my $filename = $file;
            $filename =~ s/.*\///g;
            my $index_file = ".legit/index/$filename";
            # update files in current dictory as well as in index
            copy($file, $filename) if (!-e $filename);
            copy($file, $index_file) if (!-e $index_file);
        }
    }
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
# retrieve the correct information no matter which format is used
if ($command eq "merge" && $ARGV[0] eq '-m') {
    $mg_msg = $ARGV[1];
    $mg_branch = $ARGV[2];
}
if ($command eq "merge" && $ARGV[1] eq '-m') {
    $mg_msg = $ARGV[2];
    $mg_branch = $ARGV[0];
}

if ($command eq "merge") {
    die "legit.pl: error: unknown commit '$mg_branch'\n" if ($mg_branch =~ /^\d+$/ && $mg_branch >= $version_nb);
    open FILE, '<', ".legit/branch_list" or die "$!";
    my @branches = <FILE>;
    close FILE;
    die "legit.pl: error: unknown branch '$mg_branch'\n" if (! grep(/^$mg_branch$/, @branches));
    my $current_version = first_line(".legit/branch/$current_branch/last_commit");
    my $current_origin = first_line(".legit/branch/$current_branch/originate_version");
    my $future_version;
    my $future_origin;
    # if commit number is used for merging
    if ($mg_branch =~ /^\d+$/) {
        $future_version = $mg_branch;
        foreach my $branch (@branches) {
            my $last_commit = first_line(".legit/branch/$branch/last_commit");
            if ($future_version == $last_commit) {
                die "ALready up to date\n" if ("$current_branch" eq "$branch");
                $future_origin = first_line(".legit/branch/$branch/originate_version");
                last;
            }
        }
    } else {
    # if branch name is used for merging
        die "Already up to date\n" if ("$current_branch" eq "$mg_branch");
        my $future_file = ".legit/branch/$mg_branch/last_commit";
        $future_version = first_line($future_file);
        my $future_origin_file = ".legit/branch/$mg_branch/originate_version";
        $future_origin = first_line($future_origin_file);
    }
    die "Already up to date\n" if ($future_origin == $future_version && $current_version == $future_version);
    # fast-forward merge
    if ($current_version == $future_origin && $future_version > $current_version) {
        my @bh_repo = glob ".legit/version.$future_version/*";
        # since no commit created, only copy the files in the merged repo to current directory
        # modify the last commit number and base version number in current branch accordingly
        foreach my $file (@bh_repo) {
            my $filename = $file;
            $filename =~ s/.*\///g;
            copy($file, "./$filename") or die "Copy failed $!";
            copy($file, ".legit/index/$filename") or die "Copy failed $!";
        }
        update_log($current_branch, $mg_branch);
        open my $fh, '>', ".legit/branch/$current_branch/last_commit" or die "$!";
        print $fh $future_version;
        close $fh;
        open $fh, '>', ".legit/branch/$current_branch/originate_version" or die "$!";
        print $fh $future_version;
        close $fh;
        open $fh, '>', ".legit/branch/$mg_branch/merge_version" or die "$!";
        print $fh $future_version;
        close $fh;
        print "Fast-forward: no commit created\n";
        exit 0;
        }
    # 3-way merge
    my @base_files = glob ".legit/version.$future_origin/*";
    my @branch_remote = glob ".legit/version.$future_version/*";
    my @branch_current = glob ".legit/version.$current_version/*";
    my $base_tree = ".legit/version.$future_origin/";
    my $remote_tree = ".legit/version.$future_version/";
    my $current_tree = ".legit/version.$current_version/";
    # create a temp dir to store the files that need to be merged, delete it before if existed
    rmtree ".legit/to_merge" if (-e ".legit/to_merge");
    mkdir ".legit/to_merge";
    my @conflict;
    # look for files that are in repos of two branches that are also in base repo
    foreach my $file (@base_files) {
        my $filename = $file;
        $filename =~ s/.*\///g;
        my $remote_file = $remote_tree . $filename;
        my $current_file = $current_tree . $filename;
        my $base_file = $base_tree . $filename;
        next if (! -e "$remote_file" && ! -e "$current_file");
        # push file to conflict list if base repo and only one branch has this file
        if (! -e "$remote_file" && -e "$current_file") {
            push @conflict, $filename;
            next;
        }
        if ( -e "$remote_file" && ! -e "$current_file") {
            push @conflict, $filename;
            next;
        }
        next if (compare("$base_file", "$remote_file") == 0 && compare("$base_file", "$current_file") == 0);     
        my @base_doc = read_file("$base_file");
        my @current_doc = read_file("$current_file");
        my @remote_doc = read_file("$remote_file");
        merge(\@base_doc, \@current_doc, \@remote_doc, {
            CONFLICT => sub {
                push @conflict, $filename;
            }
        });
        # if the file is conflict, skip to the next file
        next if (grep (/^$filename$/, @conflict));
        my @merged = merge(\@base_doc, \@current_doc, \@remote_doc);
        # copy non-conflict file and store it as temp file 
        # all the conflict files have to be displayed, only report conflict at the end
        open FILE, '>', ".legit/to_merge/$filename" or die "$!";
        foreach my $line (@merged) {
            print FILE $line;
        }
        close FILE; 
    }
    # Now for files not exist in base repo but exist in one of or both of the two branches
    foreach my $file (@branch_remote) {
        my $filename = $file;
        $filename =~ s/.*\///g;
        my $remote_file = $remote_tree . $filename;
        my $current_file = $current_tree . $filename;
        my $base_file = $base_tree . $filename;
        my @current_doc = read_file("$current_file") if (-e "$current_file");
        my @remote_doc = read_file("$remote_file") if (-e "$remote_file");
        if (!-e $base_file && !-e $current_file) {
            copy($remote_file, ".legit/to_merge/$filename") or die "$!";
            next;
        }
        if (!-e $base_file && -e $current_file && (@current_doc == 0 || @remote_doc == 0)) {
            copy($remote_file, ".legit/to_merge/$filename") or die "$!";
            next;
        }
        if (!-e $base_file && -e $current_file && compare($remote_file, $current_file) == 1) {
            push @conflict, $filename;
            next;
        }
        if (!-e $base_file && -e $current_file && compare($remote_file, $current_file) == 0) {
            copy($remote_file, ".legit/to_merge/$filename") or die "$!";
            next;
        }
    }
    foreach my $file (@branch_current) {
        my $filename = $file;
        $filename =~ s/.*\///g;
        my $current_file = $current_tree . $filename;
        my $base_file = $base_tree . $filename;
        if (!-e $base_file) {
            copy($current_file, ".legit/to_merge/$filename") or die "$!";
        }
    }
    # report conflict and discard merging process
    if (@conflict > 0) {
        print "legit.pl: error: These files can not be merged:\n";
        foreach my $file (sort { $a cmp $b } @conflict) {
            print "$file\n";
        }
        rmtree ".legit/to_merge" or die "$!";
        exit 1;
    }
    # modify the version record accordingly
    open my $fh, '>', ".legit/branch/$current_branch/last_commit" or die "$!";
    print $fh $version_nb;
    close $fh;
    open $fh, '>', ".legit/branch/$current_branch/originate_version" or die "$!";
    print $fh $version_nb;
    close $fh;
    open $fh, '>', ".legit/branch/$mg_branch/merge_version" or die "$!";
    print $fh $future_version;
    close $fh;
    # create a new repo dir just like commit
    my $merge_dir = ".legit/version.$version_nb";
    mkdir $merge_dir;
    foreach my $file (glob ".legit/to_merge/*") {
        my $filename = $file;
        $filename =~ s/.*\///g;
        my $remote_file = $remote_tree . $filename;
        my $current_file = $current_tree . $filename;
        my $base_file = $base_tree . $filename;
        copy($file, $filename);
        copy($file, ".legit/index/$filename");
        copy($file, "$merge_dir/$filename");
        # situations when Auto-merging prompt triggered
        # 1. the file exists in base repo, and the file in two branches are both different to the one in base repo
        # 2. the file doesn't exist in base repo, but exists in two branches, and not conflict of course. 
        if (-e $base_file && -e $remote_file && -e $current_file) {
            print "Auto-merging $filename\n" if (compare($base_file, $remote_file) == 1 && compare($base_file, $current_file) == 1);
        }
        print "Auto-merging $filename\n" if (!-e $base_file && -e $remote_file && -e $current_file);
    }
    print "Committed as commit $version_nb\n";
    # update log file, just like fast-forward, the only difference is that the new version has to the attached at the end
    update_log($current_branch, $mg_branch);
    open FILE, '>>', ".legit/branch/$current_branch/log" or die "$!";
    print FILE "$version_nb $mg_msg\n";
    close FILE;
    # delete the temp dir
    rmtree ".legit/to_merge" or die "$!";
}

