#!/usr/bin/python

# don't run this script, run words_in_dict.sh

lexicon = [line.rstrip('\n') for line in open('temp_lexicon.txt')]

temp = [line.rstrip('\n') for line in open('temp_text.txt')]
text = []
for s in temp:
	for w in s.split():
		text.append(w)

counter = 0

print "Words in text not in lexicon (number at bottom)"

for w in text:
	if w not in lexicon:
		print w
		counter+=1
		
print "\n", counter, " words"
