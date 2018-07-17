#!/bin/bash

# source 2 files to get some environment variables
. ./cmd.sh
. ./path.sh

# initialize the stage variable
stage=0

# source a file that will handle options like --stage
. ./utils/parse_options.sh

# The number of jobs you can run will depend on the system
decoding_jobs=5n
nj=56

for leaves in {3000..4000..250}
do
	for gauss in {30000..70000..10000}
	do
		# tri3b training
		if [ $stage -le 1 ]; then
			echo STAGE 1 l:$leaves g:$gauss ----------------------------------------------------
		
			# Models are speaker adapted.
			echo "Starting (SAT) triphone training in exp/tri3b on" `date`
			steps/train_sat.sh $leaves $gauss data/train \
			data/lang exp/tri2b_ali exp/tri3b_${leaves}_${gauss}
		fi

		# tri3b alignment
		if [ $stage -le 2 ]; then
			echo STAGE 2 l:$leaves g:$gauss ----------------------------------------------------
	
			echo "Starting exp/tri3b_ali on" `date`
			steps/align_fmllr.sh data/train data/lang \
			exp/tri3b_${leaves}_${gauss} exp/tri3b_${leaves}_${gauss}_ali
		fi

		# tri3b decode & test
		if [ $stage -le 3 ]; then
			echo STAGE 3 l:$leaves g:$gauss ----------------------------------------------------
	
			(
			utils/mkgraph.sh data/lang_test exp/tri3b_${leaves}_${gauss} \
			exp/tri3b_${leaves}_${gauss}/graph

			for fld in dev eval; do
				steps/decode_fmllr.sh exp/tri3b_${leaves}_${gauss}/graph \
				data/$fld exp/tri3b_${leaves}_${gauss}/decode_${fld}
			done
			) &
		fi
		
	done
	wait
done
