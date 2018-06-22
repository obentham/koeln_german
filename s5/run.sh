#!/bin/bash
# Recipe to build kaldi ASR system on the Koeln German corpus

# options
use_gp_lm=false
use_dev_and_eval_for_lm=false

# source 2 files to get some environment variables
. ./cmd.sh
. ./path.sh

# initialize the stage variable
stage=0

# source a file that will handle options like --stage
. ./utils/parse_options.sh

# Set the locations of the GlobalPhone corpus and language models
koeln_corpus=/mnt/corpora/german

gp_lexicon=/mnt/corpora/Globalphone/GlobalPhoneLexicons/German/German-GPDict.txt

# Set a variable that points to a URL for a standard German language model
gp_lm=http://www.csl.uni-bremen.de/GlobalPhone/lm/GE.3gram.lm.gz

# Set a variable to the directory where data preparation will take place
tmpdir=data/local/tmp

# The number of jobs you can run will depend on the system
decoding_jobs=5n
nj=56

# global phone data prep
if [ $stage -le 0 ]; then
	echo STAGE 0 --------------------------------------------------------------------------
	
	mkdir -p $tmpdir/lists

	# get list of globalphone .wav files
	find $koeln_corpus/read -type f -name "*.wav" > $tmpdir/lists/wav.txt

	# get list of files containing transcripts
	find $koeln_corpus/read -type f -name "*.txt" > $tmpdir/lists/trl.txt

	# assign speakers to train, dev, and eval
	if [ ! -f "conf/train_spk.list" ]; then
		for i in {1..100}; do echo "Recordings-German-$i" >> conf/train_spk.list; done
	fi
	if [ ! -f "conf/dev_spk.list" ]; then
		for i in {101..109}; do echo "Recordings-German-$i" >> conf/dev_spk.list; done
	fi
	if [ ! -f "conf/eval_spk.list" ]; then
		for i in {110..118}; do echo "Recordings-German-$i" >> conf/eval_spk.list; done
	fi

	for fld in dev eval train; do
		# each fold will have a separate working directory
		mkdir -p $tmpdir/$fld/lists

		# the conf/dev_spk.list file has a list of the speakers in the dev fold.
		# the conf/train_spk.list file has a list of the speakers in the training fold.
		# the conf/eval_spk.list file has a list of the speakers in the testing fold.
		# The following command will get the list .wav files restricted to only the speakers in 			the current fold.
		grep \
			-f conf/${fld}_spk.list $tmpdir/lists/wav.txt > \
			$tmpdir/$fld/lists/wav.txt

		sort -o $tmpdir/$fld/lists/wav.txt $tmpdir/$fld/lists/wav.txt

		# Similarly for the .trl files that contain transliterations.
		grep \
			-f conf/${fld}_spk.list $tmpdir/lists/trl.txt > \
			$tmpdir/$fld/lists/trl.txt

		sort -o $tmpdir/$fld/lists/trl.txt $tmpdir/$fld/lists/trl.txt

		# write a file with a file-id to utterance map. 
		python local/get_prompts.py $tmpdir/$fld/lists/trl.txt > $tmpdir/$fld/prompts.tsv
		# lowercase, ß to ss, remove commas in text files
		bash local/lowercase.sh $tmpdir/$fld/prompts.tsv
		bash local/remove_commas.sh $tmpdir/$fld/prompts.tsv
		bash local/ssconvert.sh $tmpdir/$fld/prompts.tsv
		
		# Acoustic model training requires 4 files containing maps:
		# 1. wav.scp
		# 2. utt2spk
		# 3. spk2utt
		# 4. text

		# make the required acoustic model training lists
		# This is first done in the temporary working directory.
		python local/make_wav_scp.py $tmpdir/$fld/lists/wav.txt > $tmpdir/$fld/lists/wav.scp
		python local/make_utt2spk.py $tmpdir/$fld/lists/wav.txt > $tmpdir/$fld/lists/utt2spk
		sort -o $tmpdir/$fld/lists/utt2spk $tmpdir/$fld/lists/utt2spk
		cat $tmpdir/$fld/prompts.tsv > $tmpdir/$fld/lists/text
		
		utils/fix_data_dir.sh $tmpdir/$fld/lists
		
		# consolidate data lists into files under data
		mkdir -p data/$fld
		for x in wav.scp text utt2spk; do
			cat $tmpdir/$fld/lists/$x | expand -t 1 | dos2unix | sort > data/$fld/$x
		done
		
		# The spk2utt file can be generated from the utt2spk file. 
		utils/utt2spk_to_spk2utt.pl data/$fld/utt2spk | sort > data/$fld/spk2utt
		
		utils/fix_data_dir.sh data/$fld	
	done
fi


# Process the pronouncing dictionary
if [ $stage -le 1 ]; then
	echo STAGE 1 --------------------------------------------------------------------------

	mkdir -p $tmpdir/dict

	# The following script is part of the original Globalphone kaldi recipe
	local/gp_norm_dict_GE.pl -i $gp_lexicon | sort -u > $tmpdir/dict/lexicon.txt

	# run lexicon through ssconvert
	bash local/ssconvert.sh $tmpdir/dict/lexicon.txt

	# Make some lists related to the lexicon
	# Including:
	# 1. A list of non-silence phones,
	# 2. A list of silence phones,
	# 3. A list of silence related questions for model clustering.
	# 4. A list of optional silence symbols
	local/prepare_dict.sh $tmpdir
	# The prepared lexicon is also written.
fi

# prepare lang directory
if [ $stage -le 2 ]; then
	echo STAGE 2 --------------------------------------------------------------------------

	# The lang directory will contain several files.
	# Including the finite state transducer file for the lexicon and grammar.
	# The lexicon fst will be stored in L.fst.
	# The grammar (ngram language model) will be stored in G.fst.
	# G.fst will be generated in a later step.
	utils/prepare_lang.sh \
	--position-dependent-phones true data/local/dict "<UNK>" \
	$tmpdir/lang_tmp $tmpdir/lang
fi

# prepare the n-gram language model
if [ $stage -le 3 ]; then
	echo STAGE 3 --------------------------------------------------------------------------

	mkdir -p data/local/lm

	if [ $use_gp_lm = true ]; then
		# get the reference lm from Bremen
		echo get the reference lm from Bremen
		wget \
		-O data/local/lm/threegram.arpa.gz \
		$gp_lm
	else
		echo create lm from corpus data
		# The following command creates an lm with the data:
		local/prepare_lm.sh $use_dev_and_eval_for_lm
	fi
	
	# Now generate the G.fst file from the lm.
	utils/format_lm.sh \
	$tmpdir/lang data/local/lm/threegram.arpa.gz data/local/dict/lexicon.txt \
	data/lang
fi
















