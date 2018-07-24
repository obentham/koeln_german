#!/usr/bin/python

# 

import sys

trl = sys.argv[1]

file = [line.rstrip('\n') for line in open(trl)]

for x in file:
	file2 = [line.rstrip('\n') for line in open(x)]
	for y in file2:
		y = y.decode("iso-8859-1").encode("utf-8")
		if not y[0] == ';' :
			print y
