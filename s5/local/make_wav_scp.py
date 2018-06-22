#!/usr/bin/python

# 

import sys
import re

wav = sys.argv[1]
pattern = re.compile('.*(Recordings-German-\d*)/(\d*).wav')

file = [line.rstrip('\n') for line in open(wav)]

for x in file:
	match = pattern.match(x)
	spk = match.group(1)
	textFile = match.group(2)
	print spk + "_" + textFile + " sox " + x + " -t .wav - |"
