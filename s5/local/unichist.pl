#!/usr/bin/perl

=head1 NAME

unichist

=head1 SYNOPSIS

unichist [--blocks] [--names] [--hex[only]] [--top=N] [--enc=ENC] [file ...]

 --blocks  : print summary of character counts per Unicode "block"
 --names   : print full Unicode character name for each code point
 --hex     : include the Unicode hexadecimal code point value
 --hexonly : show the hex code point instead of the character itself
 --top=N   : print only the N most frequent characters
 --enc=ENC : convert input from ENC to utf8 (def: input is utf8)

=head1 DESCRIPTION

For text data provided on STDIN or in one or more files named on the
command line, this program will print the list of characters occurring
in the data, together with the frequency of occurrence for each
character.

By default, input is assumed to be in utf8, and all characters present
in the input are counted and listed on STDOUT, one character per line,
in their "standard" order (i.e. the numeric ordering determined by
their Unicode code point values), with the number of occurrences
following each character.

If the input uses some known encoding other than utf8, simply name the
encoding with the "--enc=..." option (e.g. "--enc=cp1252" or
"--enc=UTF-16LE").  If the value of this option is not recognized as a
known encoding, the program exits with an error message listing the
known encodings.  (Note that ASCII is a proper subset of utf8; the
--enc option is only needed when data is neither ASCII nor utf8.)

Output is always in utf8 (but with the "--hexonly" option, it will
always be just plain ASCII).

The --hex option will put the hexadecimal code point value at the
beginning of each output line, followed by the utf8 character and then
its frequency.  Use --hexonly to output just the hexadecimal value and
frequency without the actual utf8 character itself (useful when your
display window is unable to handle utf8 data correctly).

The "--top=N" option will cause only the N most frequent characters to
be listed, in descending order of frequency.  If N is 0, no characters
will be listed (useful in combination with the "--blocks" option,
described below).  If N is -1, all characters will be listed in
descending order of frequency (instead of the default code-point
order).

The "--blocks" option will produce a supplemental set of output lines,
breaking the character counts into groups according the the "block"
pages defined by the Unicode Standard "Blocks.txt" file that comes
with your version of Perl.  Usually, a given data file would contain
characters spanning just a few distinct charts, and this form of
listing is useful when checking for "outlier characters".  To see only
this summary of character counts by chart, use this option in
combination with "--top=0", to turn off the listing of individual
characters with their frequencies.

The "--names" option will include the full Unicode name (if any) for
each code point listed in the one-character-per-line output.  Note
that some blocks of characters (e.g. the Unified CJK set) do not have
individual names for each code point.

=head1 LIMITATIONS/BUGS

Be aware that some byte sequences that are parsable as utf8 do not
correspond to defined characters -- there are gaps in the code point
sequence.  When Unicode explicitly omits some ranges of code points
as "unassigned" in "Blocks.txt", characters that fall within these
unassigned ranges will always be listed by their hex value only in
the default output, and grouped together into a single "unassigned"
class when the "--blocks" option is used.  But there are some
"unassigned" code points that we are not able to identify as such.
When in doubt, use the "--hexonly" option, and check the output
against the code charts as published at www.unicode.org/charts/.

It's also possible that unicode input might contain characters in a
region called the "Private Use Area" (UE000-UF8FF), which means that
the correct label or interpretation of the character depends on the
whim of whoever created the data.  Another possible anomaly for utf8
input is the presence of "characters" in the so-called "Surrogate Area"
(UD800-UDFFF), which indicates an encoding error by whoever created
the data.  In both cases, the default output will show only the hex
values of the observed code points in these ranges, and the "--blocks"
output will indicate these regions as "Private Use" or "Surrogate".

=head1 OTHER NOTES

The default output listing uses the symbolic names NUL, TAB, LFD, RTN,
SPC, NBSP and DEL for the null-byte, the five common whitespace
characters and \x7F, respectively; other ASCII and Latin-1 control
characters are presented in "\xHH" notation.

=head1 AUTHOR

David Graff ( graff (at) ldc (dot) upenn (dot) edu )

=cut

use strict;
use Encode;
use Getopt::Long;

my $Usage = "Usage: $0 [--blocks] [--names] [--hex[only]] [--top=N] [--enc=ENC] [file ...]\n";

my %opt;
GetOptions( \%opt, 'blocks', 'names', 'hex', 'hexonly', 'enc=s', 'top=i' )
    or die $Usage;

die $Usage if ( @ARGV == 0 and -t );

my $inmode = ':utf8';
if ( $opt{enc} ) {
    my @enclist = Encode->encodings(":all");
    listEncodings( $Usage, @enclist ) unless ( grep /$opt{enc}/, @enclist );
    $inmode = ":encoding($opt{enc})";
}

binmode STDOUT, ':utf8';
my ( %names, %char_hist, %class_hist, %class_def, %unassigned );

for my $name ( split /^/, do 'unicore/Name.pl' ) {
    chomp $name;
    my ( $h, $n ) = split /\t/, $name, 2;
    $names{chr(hex($h))} = $n;
}

# load the definitions of "chart" character classes
#  and unassigned ranges:

my $last_end = -1;
( my $blocks_path = $INC{'unicore/Name.pl'} ) =~ s/Name.pl/Blocks.txt/;
open( BLKS, "<", $blocks_path );
while (<BLKS>) {
    next unless ( /^([0-9A-F]+)\.\.([0-9A-F]+); (.*)/ );
    my ( $bgn, $end, $name ) = ( $1, $2, $3 );
    $bgn = chr( hex( $bgn ));
    $class_def{$bgn}{limit} = chr( hex( $end ));
    $class_def{$bgn}{title} = $name;
    if ( $last_end+1 != ord( $bgn )) {
        for my $val ( $last_end+1 .. ord($bgn)-1 ) {
            $unassigned{chr($val)} = undef;
        }
    }
    if ( $name =~ /Surrogate|Privat Use/ ) {
        for my $chr ( $bgn .. $class_def{$bgn}{limit} ) {
            $unassigned{$chr} = $name;
        }
    }
    $last_end = hex( $end );
}

my $max_bin = 0;
if ( @ARGV == 0 ) {
    binmode STDIN, $inmode;
    $max_bin = count_chars( \%char_hist );
} else {
    my $lcl_max;
    for my $file ( @ARGV ) {
        $lcl_max = count_chars( \%char_hist, $file, $inmode );
        $max_bin = $lcl_max if ( $max_bin < $lcl_max );
    }
}

my $nwidth = 1 + int( log( $max_bin ) / log( 10 ));
my $nonchrformat = "%04X %${nwidth}d  %s\n";
my $lblformat = ( $opt{names} ) ? "\t%${nwidth}d  %s" : "\t%${nwidth}d";
my $chrformat = ( $opt{hexonly} ) ? "%04X$lblformat\n" :
                ( $opt{hex} ) ? "%04X %4s$lblformat\n" : "%4s$lblformat\n";

# check for malformed characters and adjust histogram if needed
for my $char ( keys %char_hist ) {
    my $charnum = ( $char eq "\x00" ) ? 0 : ord( $char ) || 0xFFFD;
    if ( $charnum == 0xFFFD ) {
        $char_hist{chr($charnum)} += $char_hist{$char};
        delete $char_hist{$char};
    }
}

my @outorder;
if ( not exists( $opt{top} )) {
    @outorder = sort keys %char_hist;
}
elsif ( $opt{top} != 0 ) {
    $opt{top} = scalar keys %char_hist if ( $opt{top} < 0 );
    @outorder = ( sort {$char_hist{$b} <=> $char_hist{$a}}
                        keys %char_hist )[0 .. $opt{top}-1];
}
my %symbols = ( " " => 'SPC',
                 "\t" => 'TAB',
                 "\n" => 'LFD',
                 "\r" => 'RTN',
                 "\x00" => 'NUL',
                 "\x7F" => 'DEL',
                 "\xA0" => 'NBSP',
              );

for my $char ( @outorder ) {
    my $chrnum = ord( $char );
    if ( exists( $unassigned{$char} ) or $chrnum > $last_end ) {
        my $status = $unassigned{$char} || 'unassigned';
        printf( $nonchrformat, $chrnum, $char_hist{$char}, $status );
        next;
    }
    my @args = ();
    push @args, $chrnum if ( $chrformat =~ /X/ );
    if ( ! $opt{hexonly} ) {
        push @args, (( exists( $symbols{$char} )) ? $symbols{$char} :
                      ( $char lt ' ' || $char =~ /\x80-\x9F/ ) ? 
                       sprintf( "\\x%02x", $chrnum ) : $char );
    }
    push @args, $char_hist{$char};
    push @args, $names{$char} if ( $opt{names} );
    printf( $chrformat, @args );
}
if ( $opt{blocks} ) {
    count_classes( \%char_hist, \%class_def, \%unassigned, \%class_hist );
    print "\n";
    for my $class ( sort keys %class_def ) {
        printf( "%04x-%04x %d\t%s\n",
                ord($class), ord($class_def{$class}{limit}),
                $class_hist{$class}, $class_def{$class}{title} )
            if ( $class_hist{$class} );
    }
    printf( "xxxx-xxxx %d\t unassigned\n", $class_hist{unassigned} )
        if ( $class_hist{unassigned} );
}

sub count_chars
{
    my ( $hist, $file, $mode ) = @_;
    my $fh;
    if ( defined $file ) {
        open( $fh, "<$mode", $file ) or die "$file: $!";
    } else {
        $fh = \*STDIN;
    }
    while ( <$fh> ) {
        for my $ch ( split // ) {
            $$hist{$ch}++;
        }
    }
    my $max = 0;
    for my $c ( keys %$hist ) {
        $max = $$hist{$c} if ( $max < $$hist{$c} );
    }
    return $max;
}

sub count_classes
{
    my ( $ch_hist, $cl_def, $non_chr, $cl_hist ) = @_;

    my @start = sort keys %$cl_def;
    my $bgn = shift @start;
    for my $chr ( sort keys %$ch_hist ) {
        if ( exists( $$non_chr{$chr} )) {
            my $class = $$non_chr{$chr} || 'unassigned';
            $$cl_hist{$class}++;
            next;
        }
        while ( @start and $chr gt $$cl_def{$bgn}{limit} ) {
            $bgn = shift @start;
        }
        if ( $chr gt $$cl_def{$bgn}{limit} ) {
            $$cl_hist{unassigned} += $$ch_hist{$chr};
        } else {
            $$cl_hist{$bgn} += $$ch_hist{$chr};
        }
    }
}

sub listEncodings
{   # user is asking for help: list all available encodings
    my ( $Usage, @enclist ) = @_;
    my $colwidth = length( (sort {length($b) <=> length($a)} @enclist)[0] ) + 2;
    my $ncol = int( 80/$colwidth );
    my $nrow = int( scalar(@enclist)/$ncol );
    $nrow++ if ( scalar(@enclist) % $ncol );
    my $fmt = "%-${colwidth}s";

    print $Usage, "\n  Acceptable values for ENC are:\n";
    foreach my $r ( 0 .. $nrow ) {
        foreach my $c ( 0 .. $ncol ) {
            my $i = $c * $nrow + $r;
            printf( $fmt, $enclist[$i] );
        }
        print "\n";
    }
    exit( 0 );
}
