#!/bin/bash

# lowercases everything after the first space in the argument text file

cut -f 1 -d ' ' $1 > UID.txt
cut -f 2- -d ' ' $1 > sentence1.txt

cat sentence1.txt | perl local/tokenizer/lowercase.perl > sentence2.txt

paste UID.txt sentence2.txt -d ' ' > $1

rm UID.txt sentence1.txt sentence2.txt
