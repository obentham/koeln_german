#!/bin/bash

# takes in a file as its argument and removes all commas


sed -i -e 's/, / /g' $1
sed -i -e 's/ ,/ /g' $1
