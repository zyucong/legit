echo 123 > a
legit.pl add a
legit.pl commit -m msg
legit.pl log
legit.pl show :a
legit.pl status
legit.pl branch b0
legit.pl checkout b0
legit.pl init
legit.pl add a
legit.pl log
legit.pl show
legit.pl status
legit.pl branch b0
legit.pl checkout b0

legit.pl add a
legit.pl rm --cached a
legit.pl status
legit.pl commit -m commit0
legit.pl status
legit.pl rm --cached a
legit.pl status
echo 321 > b
legit.pl add b
legit.pl commit -m commit1
legit.pl show 1:a
legit.pl show 1:b
