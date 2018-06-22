#!/usr/bin/python

# 

import sys
import re

trl = sys.argv[1]
pattern = re.compile('.*(Recordings-German-\d*)/(\d*).txt')

file = [line.rstrip('\n') for line in open(trl)]

for x in file:
	match = pattern.match(x)
	spk = match.group(1)
	textFile = match.group(2)
	text = open(x).read().rstrip('\n')
	print spk + "_" + textFile + " " + text
