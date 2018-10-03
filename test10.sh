legit.pl init
echo hello > a
legit.pl add a
legit.pl commit -m commit0
legit.pl branch b0
legit.pl checkout b0
echo world > b
legit.pl add b
legit.pl commit -m commit1
legit.pl checkout master
echo hi > a
legit.pl add a
legit.pl commit -m update_a
legit.pl merge b0 -m msg
