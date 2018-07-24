#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 24 11:22:55 2018

@author: Oliver Bentham
"""

import random
import sys

num_sentences = int(sys.argv[1])
file_path = sys.argv[2]

sentence_list = []

for line in open(file_path):
	sentence_list.append(line.strip('\n'))

random.Random(7).shuffle(sentence_list)

for i in range(num_sentences):
	print(sentence_list[i])
