legit.pl init
echo root > root
legit.pl add root
legit.pl branch
legit.pl commit -m root
legit.pl branch y0
legit.pl branch y1
legit.pl branch
legit.pl checkout y0
echo 0 > level0
legit.pl add level0
legit.pl commit -m 0
legit.pl branch y00
legit.pl branch y01
legit.pl branch
legit.pl checkout y1
echo 1 > level0
legit.pl add level0
legit.pl commit -m 1
legit.pl branch y10
legit.pl branch y11
legit.pl branch
