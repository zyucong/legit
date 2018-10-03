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
legit.pl branch b00
legit.pl branch b01
legit.pl branch
legit.pl status
legit.pl rm --cached level0
legit.pl status
legit.pl checkout b1
echo other > level0
legit.pl status
legit.pl add level0
legit.pl status
legit.pl checkout b00
