#!/usr/bin/python

# pass run.log to this function as the only argument. Prints words not in symbol table

import sys
import re

log = sys.argv[1]
pattern = re.compile('skipped: word \'(.*)\' not in symbol table')

file = [line.rstrip('\n') for line in open(log)]

for x in file:
	match = pattern.search(x)
	if match:
		word = match.group(1)
		print word
