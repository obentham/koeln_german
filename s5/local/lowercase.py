#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 24 11:22:55 2018

@author: Oliver Bentham
"""

import sys

file_path = sys.argv[1]

sentence_list = []

for line in open(file_path):
	sentence_list.append(line.strip('\n'))

for line in sentence_list:
	print(line.lower())
