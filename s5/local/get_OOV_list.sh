#!/bin/bash

# can only be run after data/local/dict/lexicon.txt and data/local/lm/threegram.arpa
# outputs OOV.txt in koeln_german/s5/

. ./cmd.sh
. ./path.sh

gunzip -c data/local/lm/threegram.arpa.gz > data/local/lm/threegram.arpa

nohup arpa2fst --max-arpa-warnings=-1 --disambig-symbol=#0 --read-symbol-table=data/lang/words.txt data/local/lm/threegram.arpa data/lang/G.fst > OOV.txt &

sed -i -e 's/^.*word '\''//g' OOV.txt
sed -i -e 's/'\'' not.*$//g' OOV.txt
sort -u -o OOV.txt OOV.txt
sed -i '1,5d' OOV.txt
