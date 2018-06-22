#!/bin/bash

# 

lexicon=~/gp_german/s5/data/local/dict/lexicon.txt
train_text=~/gp_german/s5/data/train/text
dev_text=~/gp_german/s5/data/dev/text
eval_text=~/gp_german/s5/data/eval/text

cut -d ' ' -f 1 $lexicon > temp_lexicon.txt

cut -f 2 $train_text > temp_text.txt
cut -f 2 $dev_text >> temp_text.txt
cut -f 2 $eval_text >> temp_text.txt

python words_in_dict.py > words_in_dict.log

#rm temp_lexicon.txt temp_text.txt
