#!/usr/bin/perl -w
# get_prompts.pl - make  a prompts file
# The recordds in a prompts file  has the format:
# <FILE_ID>	<Utterance transcription>
# This  script first writes text files containing transcripts.
# The text files are stored under a directory named trl
# Then the script reads these text files and writes the prompts.tsv file

use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 1 or croak "USAGE: get_prompts.pl <FOLD>
For example:
$0 dev
";
}

use File::Basename;

my ($fld) = @ARGV;

my $tmpdir = "data/local/tmp";
my $o = "$tmpdir/$fld/prompts.tsv";
my $l = "$tmpdir/$fld/lists/trl.txt";

open my $L, '<', "$l" or croak "$l $!";

open my $O, '+>', "$o" or croak "problems with $o  $!";

while ( my $line = <$L> ) {
    chomp $line;
    my $d = dirname $line;
    my $b = basename $line, ".trl";
    my $c = basename $d;
    system "mkdir -p $tmpdir/$c";
    system "iconv \\
-f ISO_8859-1 \\
-t utf8 \\
$line \\
> \\
$tmpdir/$c/$b.txt";

    open my $T, '<', "$tmpdir/$c/$b.txt" or croak "problems with $tmpdir/$c/$b.txt $!";
    my $spkr = "";
    my $sn = 0;
    LINE: while ( my $linea = <$T> ) {
	chomp $linea;
	next LINE if ( $linea =~ /^$/);

	if ( $linea =~ /^\;SprecherID\s(\d{1,3})/ ) {
	    $spkr = $1;
	} elsif ( $linea =~ /^\;\s(\d{1,})/ ) {
	    my $n = $1;
	    print $O "GE${spkr}_${n}.adc\t";
	} else {
	    print $O "$linea\n";
	}      
    }
    close $T;
}
close $O;
