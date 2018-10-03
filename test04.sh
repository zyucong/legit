legit.pl init
echo hello > a
legit.pl add a
legit.pl commit -m msg
legit.pl branch b1
legit.pl checkout b1
echo world > a
legit.pl add a
legit.pl commit -m 1
legit.pl checkout master
echo biu > a
legit.pl add a
legit.pl commit -m master
legit.pl merge b1 -m mg
cat a
