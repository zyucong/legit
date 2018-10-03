./legit.pl init
echo root > root
./legit.pl add root
./legit.pl commit -m root
./legit.pl branch b0
./legit.pl branch b1
./legit.pl branch
./legit.pl checkout b0
seq 0 10 > 10.txt
./legit.pl add 10.txt
./legit.pl commit -m 0
cat root
./legit.pl merge b0 -m msg
# ./legit.pl show :120.txt
./legit.pl checkout master
./legit.pl merge 3 -m msg
./legit.pl merge master -m msg
./legit.pl checkout b1
seq 0 11 > 11.txt
./legit.pl add 10.txt
./legit.pl status
./legit.pl show :10.txt
./legit.pl show 0:10.txt
./legit.pl show 1:10.txt
./legit.pl show 1:root
./legit.pl show :11.txt
./legit.pl show 0:11.txt
./legit.pl show 1:root
# ./legit.pl show 1:120.txt
# ./legit.pl show 1:121.txt
./legit.pl show :root
cat root
# ls
./legit.pl status
./legit.pl commit -a -m b1
./legit.pl checkout master
./legit.pl merge b1 -m msg
cat root
./legit.pl log
echo 123 > root
./legit.pl add root
./legit.pl commit -m 4
./legit.pl checkout master
# ./legit.pl show :120.txt
./legit.pl status
./legit.pl merge b0 -m merge_b0
./legit.pl log

