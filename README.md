# legit
A simplified tool implements part of git. Try to implement as much feature as I can using perl in regard of Git. Also helps me a lot to get to know about the usage of Git.

The implemented features including

## init
```
./legit.pl init
```
## add
The add command adds the contents of one or more files to the "index".
```
./legit.pl add <filenames>
```
## commit
The commit command saves a copy of all files in the index to the repository. And commit can have a -a option which causes all files already in the index to have their contents from the current directory added to the index before the commit.
```
./legit.pl commit [-a] -m message
```
## log
Prints one line for every commit that has been made to the repository. Commits are numbered instead of hashes like git
```
./legit.pl log
```
## show
Print the contents of the specified file as of the specified commit.
If the commit is omitted the contents of the file in the index should be printed.
```
./legit.pl show [commit]:filename
```
## rm
Removes a file from the index, or from the current directory and the index.
If the --cached option is specified the file is removed only from the index and not from the current directory.
The --force option overrides both these checks.

Like git, legit will stop user from losing their work. It will give error message instead of removing the file if the file is different to the index and last commit. Various condition would be considered.
```
./legit.pl rm [--force] [--cached] <filenames>
```
## status
It shows the status of files in the current directory, index, and repository.
```
./legit.pl status
```
## branch
It either creates a branch, deletes a branch or lists current branch names.
```
./legit.pl branch [-d] [branch-name]
```
## checkout
It will switch branches
```
./legit.pl checkout branch-name
```
## merge
It adds the changes that have been made to specified branch or commit to the index and commits them.
If a file contains conflicting changes legit.pl merge produces an error message.
```
./legit.pl merge <branch-name|commit> -m message
```
