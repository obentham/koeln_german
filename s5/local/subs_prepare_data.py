#!/usr/bin/python
# -*- coding: utf-8 -*-

# 300,000

import sys 
import re 
import string
from sets import Set

lower_bound = 8
upper_bound = 25
#num_sentences = 300000

chars_to_skip = "[♪−‚–´°¬©_`=#³+-/*\{\}\[\])(\\~|@]" #ЯьΡŠûυ
profanity = "scheiss|fick| arsch|hurensohn"

# make hash with words in lexicon
#words = set()
#f = "data/lang/words.txt"
#for line in open(f):
#	words.add(line.split()[0])
#
#def has_OOV(sentence):
	


f = sys.argv[1]
counter = 1

for i, line in enumerate(open(f)):
	#if num_sentences < counter:
	#	break
		
	line_length = len(line.split())
	
	if (line_length > lower_bound and line_length < upper_bound and 
	not re.search(chars_to_skip,line) and not re.search(profanity,line)):
		
		# lowercase
		line = line.lower()
		#convert ß to ss
		line = re.sub("ß","ss",line)
		# remove common punctuation
		line = re.sub("[.!?\"\',:;]","",line)
		# convert tab to space
		line = re.sub("	"," ",line)
		# squeeze white space
		line = re.sub("\s+"," ",line)
		# remove whitespace at beginning and end of line
		line = re.sub("^\s","",line)
		line = re.sub("\s$","",line)
		#print counter, '\t', i, '\t', words, '\t', line
		print line
		counter += 1
