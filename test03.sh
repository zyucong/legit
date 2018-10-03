legit.pl init
echo root > root
legit.pl add root
legit.pl commit -m root
legit.pl branch b0
legit.pl branch b1
legit.pl branch
legit.pl checkout b0
echo 0 > level0
legit.pl add level0
legit.pl commit -m 0
legit.pl merge b0 -m msg
legit.pl checkout master
legit.pl merge 3 -m msg
legit.pl merge master -m msg
legit.pl checkout b1
echo biu > branch1

legit.pl add branch1
legit.pl commit -a -m b1
legit.pl checkout master
legit.pl merge b1 -m msg
cat root
legit.pl log
#legit.pl checkout b0
echo toor > root
legit.pl add root
legit.pl commit -m 4
legit.pl checkout master
legit.pl merge b0 -m merge_b0
legit.pl log
