#!/bin/bash -u

# Copyright 2017 John Morgan
# Apache 2.0.

set -o errexit

[ -f ./path.sh ] && . ./path.sh

# Assumes the normalized lexicon exists in the following file
d=$1/dict/lexicon.txt
# The dictionary will end up under data/local/
o=data/local/dict
if [ ! -d $o ]; then
    mkdir -p $o
fi

export LC_ALL=C

# get the phones from the dictionary
cut \
    -f2- -d "	" $d | \
    tr -s '[:space:]' '[\n*]' | grep -v SPN | sort -u > \
    $o/nonsilence_phones.txt

# remove tabs
expand \
    $d | sort -u | sed "1d" > \
    $o/lexicon.txt

# append an entry for the unknown symbol
echo "<UNK>	SPN" >> $o/lexicon.txt

# silence phones, one per line.
{
    echo SIL;
    echo SPN;
} \
    > \
    $o/silence_phones.txt

echo \
    SIL \
    > \
    $o/optional_silence.txt

(
    tr '\n' ' ' < $o/silence_phones.txt;
    echo;
    tr '\n' ' ' < $o/nonsilence_phones.txt;
    echo;
) >$o/extra_questions.txt

echo "Finished dictionary preparation."
