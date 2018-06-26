#!/usr/bin/python

# 

import sys
import re

trl = sys.argv[1]
pattern = re.compile('.*Recordings-German-(\d*)/(\d*).txt')

file = [line.rstrip('\n') for line in open(trl)]

for x in file:
	match = pattern.match(x)
	spk = match.group(1)
	textFile = match.group(2)
	text = open(x).read().rstrip('\n')
	
	append1 = ""
	append2 = ""
	if int(spk) < 10 :
		append1 = "000"
	elif int(spk) < 100 :
		append1 = "00"
	elif int(spk) < 1000 :
		append1 = "0"
		
	if int(textFile) < 10 :
		append2 = "000"
	elif int(textFile) < 100 :
		append2 = "00"
	elif int(textFile) < 1000 :
		append2 = "0"
	
	print append1 + spk + "_" + append2 + textFile + " " + text
