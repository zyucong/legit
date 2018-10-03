legit.pl init
echo aaa > a
legit.pl add a
legit.pl commit -m base
legit.pl branch b1
echo another > b
legit.pl add b
legit.pl commit -m "move on"
legit.pl log
legit.pl checkout b1
legit.pl merge master -m msg
legit.pl log
