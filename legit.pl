#!/usr/bin/perl -w

use strict;
use warnings;
use detect_change;
#use Digest::MD5;
#require "./detect_change.pl";

die "Usage: legit.pl <command> [<args>]\n" if (@ARGV == 0);
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
=put
sub is_in_repo {
	my ($to_be_deleted) = @_;
	my $version = 0;
	while ($version < $version_nb) {
		foreach my $file (glob ".legit/version.$version/*") {
			$file =~ s/.*\///g;
			return 1 if ($to_be_deleted eq $file);
		}
		$version++;
	}
	return 0;
}
=cut
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
		next if (! change_after_add($file));
		open F, '<', "$file" or die "legit.pl: error: can not open '$file'\n";
		my @lines = <F>;
		close F;
		open F, '>', "$path" or die "legit.pl: error: can not open '$path'\n";
		print F @lines;
		close F;
	}
}

if ($command eq "init") {
	die "usage: legit.pl init\n" if (@ARGV != 0);
	if (! -d -e ".legit"){
		mkdir ".legit";
		#mkdir ".legit/index";
		print "Initialized empty legit repository in .legit\n";
		exit 0;
	} else {
		die "legit.pl: error: .legit already exists\n";
	}	
}

validate;

if ($command eq "add") {
	mkdir ".legit/index" if (! -e ".legit/index");
	add(@ARGV);
=biu
	foreach my $file (@ARGV) {
		my $path = ".legit/index/$file";
		#die "legit.pl: error: can not open '$file'\n" if (! -e $file && ! -e $path);
		#unlink "$path" if (! -e $file && -e $path);
		open F, '<', "$file" or die "legit.pl: error: can not open '$file'\n";
		my @lines = <F>;
		close F;
		
		open F, '>', "$path" or die "legit.pl: error: can not open '$path'\n";
		print F @lines;
		close F;
	}
=cut
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
		open F, '<', $file or die "legit.pl: error: can not open '$file'\n";
		my @lines = <F>;
		close F;
		$file =~ s/.*\///g;
		my $path = "$dir/$file";		
		open F, '>', "$path" or die "legit.pl: error: can not open '$path'\n";
		print F @lines;
		close F;
	}
	print "Committed as commit $version_nb\n";
	open F, '>>', ".legit/log" or die "legit.pl: error: can not open log\n";
	print F "$version_nb $message\n";
	close F;
	exit 0;
}

if ($command eq "log") {
	#validate;
	die "legit.pl: error: your repository does not have any commits yet\n" if (! -e ".legit/log");
	die "usage: legit.pl log\n" if (@ARGV != 0);
	open F, '<', ".legit/log" or die "legit.pl: error: can not open log\n";
	my @commits = <F>;
	close F;
	foreach my $commit (reverse @commits) {
		print $commit;
	}
	exit 0;
}

if ($command eq "show") {
	#validate;
	die "legit.pl: error: your repository does not have any commits yet\n" if (! -e ".legit/log");
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

die "legit.pl: error: your repository does not have any commits yet\n" if ($command eq "rm" && ! -e ".legit/log");

die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && @ARGV == 0);

die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && ($ARGV[0] =~ /^--/) && !($ARGV[0] eq '--cached' || $ARGV[0] eq '--force'));

die "usage: legit.pl rm [--force] [--cached] <filenames>\n" if ($command eq "rm" && @ARGV > 1 && ($ARGV[0] =~ /^--/) && ($ARGV[1] =~ /^--/) && !($ARGV[1] eq '--cached' || $ARGV[1] eq '--force'));

# if rm a file never commit
# die "legit.pl: error: '$file' is not in the legit repository\n"
# if commit, edit, add, edit, rm
# die "legit.pl: error: '$file' in index is different to both working file and repository\n"
# if commit edit, add, rm, but still can rm --cached 
# die "legit.pl: error: '$file' has changes staged in the index"
# if commit edit rm, but still can rm --cached
# die "legit.pl: error: '$file' in repository is different to working file"

if ($command eq "rm" && $ARGV[0] eq "--cached") {
	shift @ARGV;
	foreach my $file (@ARGV) {
		#die "legit.pl: error: '$file' is not in the legit repository\n" if (! is_in_repo($file));
		my @index_files = glob ".legit/index/*";
		#my @ever_commit_files = glob ".legit/ever_commit/*";
		die "legit.pl: error: '$file' is not in the legit repository\n" if (! grep(/\/$file$/, @index_files));
		#my $in_index = ".legit/index/$file";
		die "legit.pl: error: '$file' in index is different to both working file and repository\n" if (change_after_add($file) && diff_to_repo($file));
		#print "$file\n";
		unlink ".legit/index/$file";
	}
} elsif ($command eq "rm" && !($ARGV[0] =~ /^--/)) {
	#if (!($ARGV[0] =~ /^--/)) {
	#my $cached = 0;
	#if ($ARGV[0] =~ /^--cached$/) {
	#	$cached = shift @ARGV;
	#}
	foreach my $file (@ARGV) {
		#die "legit.pl: error: '$file' is not in the legit repository\n" if (! is_in_repo($file));
		my @index_files = glob ".legit/index/*";
		my $current = $version_nb - 1;
		my @last_commit = glob ".legit/version.$current/*";
		die "legit.pl: error: '$file' is not in the legit repository\n" if (! grep(/\/$file$/, @index_files));
		my $in_index = ".legit/index/$file";
		#my $in_directory = ".legit/version.$version_nb/$file";
		#print "change_after_add($file) diff_to_repo($file)\n";
		die "legit.pl: error: '$file' has changes staged in the index\n" if (grep(/\/$file$/, @index_files) && ! grep(/\/$file$/, @last_commit));
		die "legit.pl: error: '$file' has changes staged in the index\n" if (change_after_add($file) && !diff_to_repo($file, $version_nb - 1));
		die "legit.pl: error: '$file' in index is different to both working file and repository\n" if (change_after_add($file) && diff_to_repo($file, $version_nb - 1));
		die "legit.pl: error: '$file' in repository is different to working file\n" if (!change_after_add($file) && diff_to_repo($file, $version_nb - 1));	
		#print "$file\n";
		unlink "$file" if (-e "./$file");
		unlink ".legit/index/$file" if (-e ".legit/index/$file");
	}
	#}
}
