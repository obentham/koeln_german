#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 24 11:22:55 2018

@author: Gerry Cervantes
"""

import re
import sys

lower_bound = 8
upper_bound = 25

chars_to_skip =["♪","−","‚","–","´","°","¬","©","_","`","=","#","³","+","-","/","*","{","}","[","]",")","(","~","|","@"] #ЯьΡŠûυ
profanity_list = ["scheiss","fick"," arsch","hurensohn","two and","subcentral"]



file_path = sys.argv[1]

def has_profanity(line, profanity_list):
	for profanity in profanity_list:
		if profanity in line: return True
	return False

def has_specified_chars(line, chars_to_skip):
	for invalid_char in chars_to_skip:
		if invalid_char in line: return True
	return False

def is_valid_length_line(line, lower_bound, upper_bound):
	line_length = len(line.split())
	return line_length > lower_bound and line_length < upper_bound:


for line in open(file_path):

	# lowercase
	line = line.lower()

	is_valid_line = not has_profanity(line, profanity_list) and not has_specified_chars(line, chars_to_skip)
	
	is_valid_line = is_valid_line and is_valid_length_line(line, lower_bound, upper_bound)
	
	if is_valid_line:

		# some manual lowercasingÄ
		line = re.sub("Ü", "ü", line)
		line = re.sub("Ä", "ä", line)
		line = re.sub("Ö", "ö", line)
		# convert ß to ss
		line = re.sub("ß", "ss", line)
		# remove common punctuation
		line = re.sub("[.!?\"\',:;]", "", line)
		# convert tab to space
		line = re.sub("	" ," ", line)
		# squeeze white space
		line = re.sub("\s+" ," ", line)
		# remove whitespace at beginning and end of line
		line = re.sub("^\s", "", line)
		line = re.sub("\s$", "", line)
		print(line)


