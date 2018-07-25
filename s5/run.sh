#!/bin/bash
# Recipe to build kaldi ASR system on the Koeln German corpus

# options
use_gp_lm=false
use_alt_lm=false

# if both of the above are set to false,
# an lm will be created from data with options below
include_dev_in_lm=false
include_eval_in_lm=false
include_subs_in_lm=true
include_gp_train_in_lm=true

use_gp_dict=false

# directory paths
alt_lm=~/german/lm
alt_dict=~/german/dict


# source 2 files to get some environment variables
. ./cmd.sh
. ./path.sh

# initialize the stage variable
stage=0

# source a file that will handle options like --stage
. ./utils/parse_options.sh

# Set the locations of the corpus and language models
koeln_corpus=/mnt/corpora/german
gp_corpus=/mnt/corpora/Globalphone/DEU_ASR003_WAV
subtitles=http://opus.nlpl.eu/download.php?f=OpenSubtitles2018/mono/OpenSubtitles2018.de.gz

gp_lexicon=/mnt/corpora/Globalphone/GlobalPhoneLexicons/German/German-GPDict.txt

# Set a variable that points to a URL for a standard German language model
gp_lm=http://www.csl.uni-bremen.de/GlobalPhone/lm/GE.3gram.lm.gz

# Set a variable to the directory where data preparation will take place
tmpdir=data/local/tmp

# The number of jobs you can run will depend on the system
decoding_jobs=5n
nj=56

if [ $stage -le -1 ]; then
	if [ $use_gp_lm = false ] && [ $use_alt_lm = false ] && [ $include_subs_in_lm = true ]; then
		echo downloading subtitles
		mkdir -p $tmpdir/subs
		wget -nv -O $tmpdir/subs/subs.de.gz $subtitles
		echo unzipping subtitles
		gunzip -c $tmpdir/subs/subs.de.gz > $tmpdir/subs/subs.txt 
	fi
fi

# data prep
if [ $stage -le 0 ]; then
	echo STAGE 0 --------------------------------------------------------------------------
	
	mkdir -p $tmpdir/lists

	# get list of globalphone .wav files
	find $koeln_corpus/read -type f -name "*.wav" > $tmpdir/lists/wav.txt
	find $gp_corpus/adc -type f -name "*.wav" >> $tmpdir/lists/wav.txt

	# get list of files containing transcripts
	find $koeln_corpus/read -type f -name "*.txt" > $tmpdir/lists/trl.txt
	find $gp_corpus/trl -type f -name "*.trl" >> $tmpdir/lists/trl.txt

	rm conf/train_spk.list 
	# rm conf/dev_spk.list conf/eval_spk.list

	# assign speakers to train, dev, and eval
	for i in {1..118}; do echo "Recordings-German-$i" >> conf/train_spk.list; done
	# for i in {1..100}; do echo "Recordings-German-$i" >> conf/train_spk.list; done
	# for i in {101..109}; do echo "Recordings-German-$i" >> conf/dev_spk.list; done
	# for i in {110..118}; do echo "Recordings-German-$i" >> conf/eval_spk.list; done

	# Create train from Koeln data
	for fld in train; do
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
	
	# Create dev and eval from GlobalPhone data
	for fld in dev eval; do
		# each fold will have a separate working directory
		mkdir -p $tmpdir/$fld/lists

		# the conf/dev_spk.list file has a list of the speakers in the dev fold.
		# the conf/train_spk.list file has a list of the speakers in the training fold.
		# the conf/eval_spk.list file has a list of the speakers in the testing fold.
		# The following command will get the list .wav files restricted to only the speakers in 			the current fold.
		grep \
			-f conf/${fld}_spk.list $tmpdir/lists/wav.txt > \
			$tmpdir/$fld/lists/wav.txt

		# Similarly for the .trl files that contain transliterations.
		grep \
			-f conf/${fld}_spk.list $tmpdir/lists/trl.txt > \
			$tmpdir/$fld/lists/trl.txt

		# write a file with a file-id to utterance map. 
		local/get_prompts.pl $fld

		# Acoustic model training requires 4 files containing maps:
		# 1. wav.scp
		# 2. utt2spk
		# 3. spk2utt
		# 4. text

		# make the required acoustic model training lists
		# This is first done in the temporary working directory.
		local/make_lists.pl $fld

		utils/fix_data_dir.sh $tmpdir/$fld/lists

		# consolidate data lists into files under data
		mkdir -p data/$fld
		for x in wav.scp text utt2spk; do
			# lowercase, ß to ss, remove commas in text files
			if [ "$x" == "text" ]; then
				echo "lowercase, ß to ss, remove commas in text files"
				bash local/lowercase.sh $tmpdir/$fld/lists/text
				bash local/ssconvert.sh $tmpdir/$fld/lists/text
				bash local/remove_commas.sh $tmpdir/$fld/lists/text
				cat $tmpdir/$fld/lists/$x | expand -t 1 | dos2unix | sort > data/$fld/$x
			else
				cat $tmpdir/$fld/lists/$x | expand -t 1 | dos2unix | sort > data/$fld/$x
			fi
		done

		# The spk2utt file can be generated from the utt2spk file. 
		utils/utt2spk_to_spk2utt.pl data/$fld/utt2spk | sort > data/$fld/spk2utt

		utils/fix_data_dir.sh data/$fld
	done
	
	# This is the data preparation for the unlabeled data to be used in semi-supervised learning
	mkdir -p $tmpdir/unlabeled/lists

	# get list of globalphone .wav files
	find $koeln_corpus/CTELL1 -type f -name "*.wav" > $tmpdir/unlabeled/lists/wav.txt
	find $koeln_corpus/CTELL2 -type f -name "*.wav" >> $tmpdir/unlabeled/lists/wav.txt
	find $koeln_corpus/CTELL3 -type f -name "*.wav" >> $tmpdir/unlabeled/lists/wav.txt
	find $koeln_corpus/CTELL4 -type f -name "*.wav" >> $tmpdir/unlabeled/lists/wav.txt
	find $koeln_corpus/CTELL5 -type f -name "*.wav" >> $tmpdir/unlabeled/lists/wav.txt
	
	rm -f conf/unlabeled_spk.list 
	# rm conf/dev_spk.list conf/eval_spk.list

	# assign speakers to train, dev, and eval
	for i in {1..118}; do echo "Answers-German-$i" >> conf/unlabeled_spk.list; done

	sort -o $tmpdir/unlabeled/lists/wav.txt $tmpdir/unlabeled/lists/wav.txt

	# write a file with a file-id to utterance map. 
	python local/semi_supervised/get_prompts.py \
		$tmpdir/unlabeled/lists/wav.txt > $tmpdir/unlabeled/prompts.tsv

	# Acoustic model training requires 4 files containing maps:
	# 1. wav.scp
	# 2. utt2spk
	# 3. spk2utt
	# 4. text

	# make the required acoustic model training lists
	# This is first done in the temporary working directory.
	python local/semi_supervised/make_wav_scp.py \
		$tmpdir/unlabeled/lists/wav.txt > $tmpdir/unlabeled/lists/wav.scp
	python local/semi_supervised/make_utt2spk.py \
		$tmpdir/unlabeled/lists/wav.txt > $tmpdir/unlabeled/lists/utt2spk
	sort -o $tmpdir/unlabeled/lists/utt2spk $tmpdir/unlabeled/lists/utt2spk
	cat $tmpdir/unlabeled/prompts.tsv > $tmpdir/unlabeled/lists/text
		
	utils/fix_data_dir.sh $tmpdir/unlabeled/lists
	
	# consolidate data lists into files under data
	mkdir -p data/unlabeled
	for x in wav.scp text utt2spk; do
		cat $tmpdir/unlabeled/lists/$x | expand -t 1 | dos2unix | sort > data/unlabeled/$x
	done
		
	# The spk2utt file can be generated from the utt2spk file. 
	utils/utt2spk_to_spk2utt.pl data/unlabeled/utt2spk | sort > data/unlabeled/spk2utt
	
	utils/fix_data_dir.sh data/unlabeled
fi

# Process the pronouncing dictionary
if [ $stage -le 1 ]; then
	echo STAGE 1 --------------------------------------------------------------------------

	if [ $use_gp_dict = true ]; then
		echo using gp dictionary
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
	else
		echo using alternate dictionary
		rm -f -r data/local/dict
		cp -r $alt_dict data/local/dict
	fi
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
	elif [ $use_alt_lm = true ]; then
		echo using alternate lm
		rm -f -r data/local/lm
		cp -r $alt_lm data/local/lm
	else
		echo create lm from corpus data

		# use training prompts
		cut -f 2- -d ' ' data/train/text > data/local/lm/training_text.txt
		if [ $include_dev_in_lm = true ]; then
			cut -f 2- -d ' ' data/dev/text >> data/local/lm/training_text.txt
		fi
		if [ $include_eval_in_lm = true ]; then
			cut -f 2- -d ' ' data/eval/text >> data/local/lm/training_text.txt
		fi
		if [ $include_subs_in_lm = true ]; then
			echo processing subtitles
			if [ ! -f $tmpdir/subs/subs.txt ]; then
				echo subtitles not downloaded, downloading now
				mkdir -p $tmpdir/subs
				wget -nv -O $tmpdir/subs/subs.de.gz $subtitles
				echo unzipping subtitles
				gunzip -c $tmpdir/subs/subs.de.gz > $tmpdir/subs/subs.txt 
			fi
			python local/subs_prepare_data.py $tmpdir/subs/subs.txt \
				> $tmpdir/subs/subs_filtered.txt
			sort -u $tmpdir/subs/subs_filtered.txt > $tmpdir/subs/subs_uniq.txt
			python local/select_n.py 1000000 $tmpdir/subs/subs_uniq.txt \
				> $tmpdir/subs/subs_final.txt
			cat $tmpdir/subs/subs_final.txt >> data/local/lm/training_text.txt
		fi
		if [ $include_gp_train_in_lm = true ]; then
			echo include gp train in lm
			mkdir -p $tmpdir/gp_train
			
			grep \
			-f conf/gp_train_spk.list $tmpdir/lists/trl.txt > \
				$tmpdir/gp_train/files
			
			python local/get_gp_prompts.py $tmpdir/gp_train/files > \
				$tmpdir/gp_train/text
			
			python local/lowercase.py $tmpdir/gp_train/text > $tmpdir/gp_train/text_lowercase.txt
			mv $tmpdir/gp_train/text_lowercase.txt $tmpdir/gp_train/text
			bash local/ssconvert.sh $tmpdir/gp_train/text
			bash local/remove_commas.sh $tmpdir/gp_train/text
			cat $tmpdir/gp_train/text | expand -t 1 | dos2unix | sort -u -o $tmpdir/gp_train/text
			
			cut -f 2- -d ' ' $tmpdir/gp_train/text >> data/local/lm/training_text.txt	
			
		fi
		
		# The following command creates an lm with the data:
		local/prepare_lm.sh
	fi
	
	# Now generate the G.fst file from the lm.
	utils/format_lm.sh \
	$tmpdir/lang data/local/lm/threegram.arpa.gz data/local/dict/lexicon.txt \
	data/lang
fi

# create ConstArpaLm format language model
if [ $stage -le 4 ]; then
	echo STAGE 4 --------------------------------------------------------------------------
	
	# Notice that it ends up under data/lang_test
	utils/build_const_arpa_lm.sh \
	data/local/lm/threegram.arpa.gz \
	data/lang \
	data/lang_test
fi

# extract acoustic features
if [ $stage -le 5 ]; then
	echo STAGE 5 --------------------------------------------------------------------------

	# This stage will create the exp directory where most of the rest of the work will take place.
	# The feature files will be stored under plp_pitch
	# plp and pitch features are extracted.
	for fld in dev eval train unlabeled ; do
		steps/make_plp_pitch.sh data/$fld exp/make_plp_pitch/$fld plp_pitch

		utils/fix_data_dir.sh data/$fld

		steps/compute_cmvn_stats.sh data/$fld exp/make_plp_pitch/$fld plp_pitch

		utils/fix_data_dir.sh data/$fld
	done
fi

# monophone training
if [ $stage -le 6 ]; then
	echo STAGE 6 --------------------------------------------------------------------------

	# This is the first of several acoustic model training steps.
	# Context independent phones are trained.
	echo "Starting monophone training in exp/mono on" `date`
	steps/train_mono.sh data/train data/lang exp/mono
fi

# monophone alignment
if [ $stage -le 7 ]; then
	echo STAGE 7 --------------------------------------------------------------------------

	# This step uses the monophones just trained to time align the data
	steps/align_si.sh data/train data/lang exp/mono exp/mono_ali
fi

# monophone decode & test
if [ $stage -le 8 ]; then
	echo STAGE 8 --------------------------------------------------------------------------

	# Test the monophone models.
	(
	# A graph is required for decoding.
	utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph

	for fld in dev eval; do
		# The following command does speech recognition using the monophone models 
		steps/decode.sh exp/mono/graph data/$fld exp/mono/decode_${fld}
	done
	) &
	# Testing can be run in the background
fi

# tri1 training
if [ $stage -le 9 ]; then
	echo STAGE 9 --------------------------------------------------------------------------
	
	# This is the first step for training context dependent acoustic models
	echo "Starting triphone training in exp/tri1 on" `date`
	steps/train_deltas.sh \
	--cluster-thresh 100 3100 50000 data/train data/lang exp/mono_ali \
	exp/tri1
fi

# tri1 alignment
if [ $stage -le 10 ]; then
	echo STAGE 10 --------------------------------------------------------------------------
	
	# align with triphones
	steps/align_si.sh data/train data/lang exp/tri1 exp/tri1_ali
fi

# tri1 decode & test
if [ $stage -le 11 ]; then
	echo STAGE 11 --------------------------------------------------------------------------
	
	# Test the triphone models.
	(
	utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph

	for fld in dev eval; do
		steps/decode.sh exp/tri1/graph data/$fld exp/tri1/decode_${fld}
	done
	) &
fi

# tri2b training
if [ $stage -le 12 ]; then
	echo STAGE 12 --------------------------------------------------------------------------
	
	# Trains with front end feature adaptation.
	echo "Starting (lda_mllt) triphone training in exp/tri2b on" `date`
	steps/train_lda_mllt.sh \
	--splice-opts "--left-context=3 --right-context=3" \
	3100 50000 data/train data/lang exp/tri1_ali exp/tri2b
fi

# tri2b alignment
if [ $stage -le 13 ]; then
	echo STAGE 13 --------------------------------------------------------------------------
	
	# align with lda and mllt adapted triphones
	steps/align_si.sh \
	--use-graphs true data/train data/lang exp/tri2b exp/tri2b_ali
fi

# tri2b decode & test
if [ $stage -le 14 ]; then
	echo STAGE 14 --------------------------------------------------------------------------
	
	# Decode tri2b
	(
	utils/mkgraph.sh data/lang_test exp/tri2b exp/tri2b/graph

	for fld in dev eval; do
		steps/decode.sh exp/tri2b/graph data/$fld exp/tri2b/decode_${fld}
	done
	) &
fi

# tri3b training
if [ $stage -le 15 ]; then
	echo STAGE 15 --------------------------------------------------------------------------
	
	# Models are speaker adapted.
		echo "Starting (SAT) triphone training in exp/tri3b on" `date`
	steps/train_sat.sh 3100 50000 data/train data/lang exp/tri2b_ali exp/tri3b
fi

# tri3b alignment
if [ $stage -le 16 ]; then
	echo STAGE 16 --------------------------------------------------------------------------
	
	echo "Starting exp/tri3b_ali on" `date`
	steps/align_fmllr.sh data/train data/lang exp/tri3b exp/tri3b_ali
fi

# tri3b decode & test
if [ $stage -le 17 ]; then
	echo STAGE 17 --------------------------------------------------------------------------
	
	(
	utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph

	for fld in dev eval unlabeled ; do
		steps/decode_fmllr.sh \
		exp/tri3b/graph data/$fld exp/tri3b/decode_${fld}
	done
	) &
fi

# chain models train, decode, and test
if [ $stage -le 18 ]; then
	echo STAGE 18 --------------------------------------------------------------------------
	
	local/chain/run_tdnn.sh
fi

