#!/bin/bash
# Recipe to build kaldi ASR system on the Koeln German corpus

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

#  set a variable to the directory where  data preparation will take place
tmpdir=data/tmp

# The number of jobs you can run will depend on the system
decoding_jobs=5n
nj=56

# global phone data prep
if [ $stage -le 0 ]; then
    
    mkdir -p $tmpdir/lists

    # get list of globalphone .wav files
    find $koeln_corpus/read -type f -name "*.wav" > $tmpdir/lists/wav.txt

	# get list of files containing  transcripts
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
	    	-f conf/${fld}_spk.list  $tmpdir/lists/wav.txt  > \
	    	$tmpdir/$fld/lists/wav.txt

		# Similarly for the .trl files that contain transliterations.
		grep \
		    -f conf/${fld}_spk.list  $tmpdir/lists/trl.txt  > \
		    $tmpdir/$fld/lists/trl.txt

		# write a file with a file-id to utterance map. 
		local/get_prompts.pl $fld

done
		"# Acoustic model training requires 4 files containing maps:
		# 1. wav.scp
		# 2. utt2spk
		# 3. spk2utt
		# 4. text

		# make the required acoustic model training lists
		# This is first done in the temporary working directory.
		local/make_lists.pl $fld

		utils/fix_data_dir.sh $tmpdir/$fld/lists

		# consolidate  data lists into files under data
		mkdir -p data/$fld
		for x in wav.scp text utt2spk; do
			# lowercase, ß to ss, remove commas in text files
			if [ "$x" == text (in quotes) ]; then
				bash local/lowercase.sh $tmpdir/$fld/lists
				bash local/ssconvert.sh $tmpdir/$fld/lists/text
				bash local/remove_commas.sh $tmpdir/$fld/lists/text
				cat $tmpdir/$fld/lists/$x | expand -t 1 | dos2unix | sort >> data/$fld/$x
			else
				cat $tmpdir/$fld/lists/$x | expand -t 1 | dos2unix | sort >> data/$fld/$x
			fi
		done

		# The spk2utt file can be generated from the utt2spk file. 
		utils/utt2spk_to_spk2utt.pl data/$fld/utt2spk | sort > data/$fld/spk2utt

		utils/fix_data_dir.sh data/$fld
    done"
fi
