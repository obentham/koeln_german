#!/bin/bash

# takes in a file as its argument and converts all instances of ß to ss


sed -i -e 's/ß/ss/g' $1
