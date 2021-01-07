#!/usr/bin/perl
# Written by Craig Maloney
# (c) 2005 Craig Maloney
# Modified Nov-Dec. 2005 by Lars Huttar (lars AT huttar dot net)
# Enhanced Jan. 2021 by Onkobu Tanaake (onkobu at onkobutanaake dot de)
# Released under the GPL

use strict;
use warnings;

# Use Unicode:
use open ':utf8';
use open ':std';

my $version_number = "1.4.3";
use Getopt::Long;

# DEFAULTS
my $debug = 0; # Print debugging messages or not
my $wordfile = "/usr/share/dict/words"; # Location of the words to use by default
my $num_of_words = 50; # Number of words to place in puzzle
my $gridsize = 40; # How big should the puzzle be?
my $directions = 8; # Number of directions?
my $max_iterations = 5;     # Maximum number of times to try before using drastic measures
my $nogrow = 0; # Don't grow the puzzle beyond the initial size
my $svg = 0; # Print solutions in SVG format 
my $finished = 0;     # Main loop toggle
my $lowercase = 0; # Toggle lowercase
my $checkunique = 0; # Check to see if words are unique 
my $intersections = 0; # Number of cells where words intersect
my $rtl = 0; # Use right-to-left instead of left-to-right
my $min_word_length = 5; # Minimum word length 
my $similar_words = 0; # Don't allow duplicates at $min_word_length number of letters
my $fillalphabet = 0; # Use the letters from the wordlist
my $no_normalize = 0; # Allow the input to be used as it is, no post processing
my $all = 0; # Don't use all of the words
my $html; # render plain text instead of HTML
my $title = "Word Search";
my @grid; # where all the letters and word are stored

# List of words to choose from.
my @wordlist = ();
# List of words chosen for puzzle.
my @selected_words = ();
# Offsets for the eight directions.
my @x_offset = (1,0,0,-1,1,1,-1,-1); # R,D,U,L,UR,DR,DL,UL
my @y_offset = (0,1,-1,0,-1,1,1,-1); # R,D,U,L,UR,DR,DL,UL

my $fillwithquote;

my $nosolution;

my $version; # show version

my $quick;

my $thorough;

my $help;

# decoration for default output format text/plain
# --html changes this to HTML for example
#
my $start_section = \&start_section_text;
my $end_section = \&end_section_text;
my $start_grid = \&start_grid_text;
my $end_grid = \&end_grid_text;
my $start_row = \&start_row_text;
my $end_row = \&end_row_text;
my $start_col = \&start_col_text;
my $end_col =  \&end_col_text;
my $print_words = \&print_words_text;
my $print_header = \&print_header_text;
my $print_footer = \&print_footer_text;
my $print_heading = \&print_heading_text;

# @fillwith = split //, "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ";
# @fillwith = split //, "_";

GetOptions ("size=i" => \$gridsize,
    "directions=i" => \$directions,
    "words=i" => \$num_of_words,
    "all" => \$all,
    "wordfile=s" => \$wordfile,
    "fillwithquote" => \$fillwithquote,
    "fillalphabet" => \$fillalphabet,
    "checkunique" => \$checkunique,
    "lowercase" => \$lowercase,
    "debug" => \$debug,
    "nosolution" => \$nosolution,
    "svg" => \$svg,
    "html" => \$html, 
    "nogrow" => \$nogrow,
    "version" => \$version,
    "quick" => \$quick,
    "thorough" => \$thorough,
    "righttoleft" => \$rtl,
    "similarwords" => \$similar_words,
    "minwordlength=i" => \$min_word_length,
    "nonormalize" => \$no_normalize,
    "help" => \$help,
	"title=s" => \$title);
# all = try to place every word in the wordlist into the puzzle.

if ($help) {
    &usage;
    exit(0);
}

if ($version) {
    print "$0 version: $version_number\n";
    exit(0);
}

if ($quick) {
    $max_iterations = 1;
}

if ($thorough) {
    $max_iterations = 20;
}

if ($html) {
	$start_section = \&start_section_html;
	$end_section = \&end_section_html;
	$start_grid = \&start_grid_html;
	$end_grid = \&end_grid_html;
	$start_row = \&start_row_html;
	$end_row = \&end_row_html;
	$start_col = \&start_col_html;
	$end_col = \&end_col_html;
	$print_words = \&print_words_html;
	$print_header = \&print_header_html;
	$print_footer = \&print_footer_html;
	$print_heading = \&print_heading_html;
}

open WORDLIST, "$wordfile" || die "Can't open wordlist $wordfile\n";
foreach my $i (<WORDLIST>) {
    chomp $i; # remove line ending
    next if length $i < $min_word_length;
    push @wordlist, normalize($i) if ($i ne '' && $i ne ' ');
}
close WORDLIST;

my @fillwith;
my $spaces_left;

if ($fillwithquote) {
    # Last line becomes a quote to use as filler.
    @fillwith = split('', normalize(pop @wordlist));
}

# Randomize the list
for (my $i = ((scalar @wordlist)); --$i; ) {
    my $j = int rand ($i);
    next if $i == $j;
    @wordlist[$i,$j] = @wordlist[$j,$i];
}

if ($all) {
    $num_of_words = scalar @wordlist;
    @selected_words = @wordlist;
    $similar_words = 1;
}

if (!$similar_words) { # Remove similar words
    my %duplicate_words = ();
    my $i = 0;
    while (($i < $num_of_words) && (scalar @wordlist > 0)) {
        my $word = pop @wordlist;
        if (! $duplicate_words{substr($word,0,$min_word_length)}) {
            $duplicate_words{substr($word,0,$min_word_length)} = 1;
            push @selected_words, $word;
            $i++;
        } else {
            warn "Word too similar: $word\n";
        }
    }

    if (scalar @selected_words < $num_of_words) {
        $num_of_words = scalar @selected_words;
        warn "Updating number of words to $num_of_words\n";
    }
}

die "No words to use. Exiting.\n" if (scalar @selected_words <= 0);

@wordlist = ();
@selected_words = sort { length $a <=> length $b } @selected_words;

# @fillwith = set of letters to use for filling in blanks: Use letters from
# hidden words.  This gets rid of the problem of using A-Z when the hidden
# words are in other alphabets.  It also makes the puzzle harder by making
# "foreground and background" more closely resemble each other in letter
# frequency.
if (!$fillwithquote && !$fillalphabet) {
        @fillwith = split (//, join('', @selected_words)); 
} else { 
        @fillwith = split //, normalize("ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ");
}

# Global state, manipulated in subs
#
my $words_placed = 0;
my @word_x_starts = ();
my @word_y_starts = ();
my @word_dirs = ();
my @letters;

# Main loop
do {
    my $completely_done = $num_of_words;
    my $number_of_iterations=0;

    # Arrays storing placement of words. This should be a 2D array or some more
    # sophisticated data structure, instead of 3 arrays; but I (Lars) find those too difficult in Perl. :-(

    while ($completely_done > 0 && $number_of_iterations < $max_iterations) {
        print "Creating new puzzle $number_of_iterations\n" if $debug;
        $intersections = 0;
        $spaces_left = $gridsize * $gridsize;
        $number_of_iterations++;
        $completely_done = $num_of_words;
        my $success = 1;
        my @new_word_list = @selected_words;
        &clear_grid;
        while ((my $new_word = pop @new_word_list) && $success) {
            print "Placing $new_word\n" if $debug;
            my $results = &place_word($new_word, $gridsize, $directions, $words_placed);
            if ($results == 0) {
                $completely_done--; 
                $words_placed++;
            } else {
                print "iterating over grid\n" if $debug;
                $results = &iterate_word($new_word, $gridsize, $directions);
                if ($results != 0) {
                    print "Grid iteration didn't work either\n" if $debug;
                    $success = 0;
                } else {
                    $completely_done--;
                    $words_placed++;
                }
            }
        }
    }
    print "Number of main loop iterations = $number_of_iterations\n" if $debug;
    if ($completely_done > 0) {
        if ($nogrow) {
            die "Can't create wordsearch with these parameters. Aborting.\n";
        } else {
            $gridsize += 5;
            warn "Increasing gridsize to $gridsize\n";
        }
    }
    if ($fillwithquote) {
               if  (scalar @fillwith != $spaces_left) {
                   print "Spaces left: $spaces_left != quote length: ", scalar @fillwith, ".\n" if $debug;
                   print_grid(1) if $debug;
                   if ($number_of_iterations >= $max_iterations) { $finished = 1; }
                   else { print "Trying again.\n" if $debug; }
               } else {
                   print "Quote fits in remaining spaces!\n" if $debug;
                   $finished = 1;
               }
    } else {
        $finished = 1;
    }
} until ($finished);

$print_header->();

if (!$nosolution && !$svg) {
	$start_section->("solution");
    &print_grid(1);
	$end_section->();
}

&fill_in();
if ($checkunique) { check_unique(); }
print "\n";

if (!$nosolution && $svg) {
   	$start_section->("solution");
    &print_solution_svg();
	$end_section->();
}

$start_section->("grid");
&print_grid(0);
print "\n\n";

@selected_words = sort @selected_words;
$print_words->();
$end_section->();

$print_footer->();
exit(0);

# Try to place word randomly; return 0 if successful.
sub place_word {
    my ($word, $size, $possible_directions, $words_placed) = @_;
    my $done = 0;
    @letters = split //,$word;
    my $iteration_counter = 0;

            # First, try to place word in a way that intersects another word.
    while (!$done && $words_placed > 0 && ($size * $size * 0.1 >= $iteration_counter) ) {
        my $x = int (rand $size);
        my $y = int (rand $size);

        if (!is_empty($x, $y) && $word =~ /$grid[$y][$x]/)
        {
            $done = &try_word_around($word, $x, $y, $size, $possible_directions);
        }

        $iteration_counter++;
    }
    if ($done && $debug) {
        print "Placed word intersectingly\n";
        print_grid(1);
    }

            if (!$done) {
                        # If that didn't work, just try to place the word randomly. 
                $iteration_counter = 0;            
                        
                while (!$done && (2*$num_of_words >= $iteration_counter) ) {
                    my $x = int (rand $size);
                    my $y = int (rand $size);
            
                    #if (is_empty($x, $y)) 
                    {
                        $done = &test_word_position($x, $y, $size, $possible_directions);
                    }
            
                    $iteration_counter++;
                }
            }
            
    if (!$done) {
        print "Random iterations failed: $iteration_counter\n" if $debug;
        return 1;
    }
    print "Random Iterations $iteration_counter\n" if $debug;
    return 0;
}

# Try to place word systematically; return 0 if successful.
sub iterate_word {
    my ($word,$size,$possible_directions) = @_;
    my $done = 0;
    @letters = split //,$word;
    my $x=0;
    my $y=0;
    while (!$done && ($y<$size) ) {
        if (is_empty($x, $y)) {
            $done = &test_word_position($x,$y,$size,$possible_directions);
        }

        $x++;
        if ($x>=$size) {
            $x=0;
            $y++;
        }
    }
    if (!$done) {
        return 1;
    }
    return 0;
}

sub print_grid {
    my $solution = shift;
    if ($solution && $svg) {
        print_solution_svg();
    } else {
		$print_heading -> ("Solution") if $solution;
		$start_grid -> ();
        for (my $i=0; $i<$gridsize; $i++) {
			$start_row->();
            for (my $j=0; $j<$gridsize; $j++) {
				$start_col->();
                print $grid[$i][$j];
				$end_col->();
            }
			$end_row->();
        }
		$end_grid -> ();
		$print_heading -> ("Grid") if $solution;
        print("Intersections: $intersections\n") if $debug;
    }
}

sub print_solution_svg() {
	my $margin = 20;
	my $dx = 20;
	my $dy = 20;
	$print_heading->("Solution");
	if ($html) {
		printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d">', $dx*($gridsize+1), $dy*($gridsize+1);
		print "\n";
	} else {
		print "<?xml version='1.0' encoding='UTF-8'?>\n";
		print "<!DOCTYPE svg PUBLIC '-//W3C//DTD SVG 1.0//EN' 'http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd'>\n";
		print "<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='100%'>\n";
	} 
	print "  <g style='stroke-linecap: round; stroke: #7777ff; stroke-width: 6; opacity: 0.5'>\n";
	for (my $i = 0; $i < $words_placed; $i++ ) {
		my $word = $selected_words[$i];
		printf("    <!-- word: %s -->\n", $selected_words[$i]);
		my $x1 = $margin + $word_x_starts[$i] * $dx - 2;
		my $y1 = $margin + $word_y_starts[$i] * $dy - 6;
		my $x2 = $x1 + $x_offset[$word_dirs[$i]] * $dx * (length($word)-1);
		my $y2 = $y1 + $y_offset[$word_dirs[$i]] * $dy * (length($word)-1);
		printf("    <line x1='%d' y1='%d' x2='%d' y2='%d'/>\n", $x1, $y1, $x2, $y2);
	}
	print "  </g>\n";
	print "  <text style='text-anchor: middle'>\n";
	for (my $i=0; $i<$gridsize; $i++) {
		for (my $j=0; $j<$gridsize; $j++) {
			my $x = $margin + $j * $dx;
			my $y = $margin + $i * $dy;
			printf("    <tspan x='%d' y='%d'>%s</tspan>\n", $x, $y, $grid[$i][$j]);
		}
		print "\n";
	}
	print "  </text>\n";
	
	print "</svg>\n";
	$print_heading -> ("Grid");
	print("Intersections: $intersections\n") if $debug;
}

# Fill in remaining spaces with either letters from the quote, or random letters.
sub fill_in {
    my $quoteindex = 0;
    for (my $i=0; $i < $gridsize; $i++) {
        if ($fillwithquote) {
            if ($rtl) {
                # Right to left
                for (my $j = $gridsize-1; $j >= 0; $j--) {
                       if (is_empty($j, $i)) {
                        if ($quoteindex > $#fillwith) { $grid[$i][$j] = '_'; }
                        else { $grid[$i][$j] = $fillwith[$quoteindex++]; }
                    }
                }    
            } else {
                for (my $j=0; $j < $gridsize; $j++) {
                       if (is_empty($j, $i)) {
                        if ($quoteindex > $#fillwith) { $grid[$i][$j] = '_'; }
                        else { $grid[$i][$j] = $fillwith[$quoteindex++]; }
                    }
                }
            }
        } else {
            for (my $j=0; $j < $gridsize; $j++) {
               if (is_empty($j, $i)) {
                    $grid[$i][$j] = $fillwith[rand @fillwith];
               }
            }
        }
    } 
}

# is_empty($x, $y):
# Return a true value if the grid cell at x,y is empty.
sub is_empty {
    my $x = shift;
    my $y = shift;
    return (!$grid[$y][$x] || $grid[$y][$x] eq '' || $grid[$y][$x] eq '-');
}

# Display the words to search for, in multi-column format.
sub print_words_text {
    # Copied from Perl Cookbook by Tom Christiansen & Nathan Torkington
    # Recipie 4.18
    my ($item, $cols, $rows, $maxlen);
    my ($xpixel, $ypixel, $mask, @data);
    $cols = 80;
    $maxlen = 1;        
    foreach my $word (@selected_words) {
        my $mylen;
        $word =~ s/\s+$//;
        $maxlen = $mylen if (($mylen = length $word) > $maxlen);
        push(@data, $word);
    }

    $maxlen += 1;               # to make extra space

    # determine boundaries of screen
    $cols = int($cols / $maxlen) || 1;
    $rows = int(($#data+$cols) / $cols);

    # pre-create mask for faster computation
    $mask = sprintf("%%-%ds ", $maxlen-1);

    # subroutine to check whether at last item on line
    sub EOL { ($item+1) % $cols == 0 }  

    # now process each item, picking out proper piece for this position
    for ($item = 0; $item < $rows * $cols; $item++) {
        my $target =  ($item % $cols) * $rows + int($item/$cols);
        my $piece = sprintf($mask, $target < @data ? $data[$target] : "");
        $piece =~ s/\s+$// if EOL();  # don't blank-pad to EOL
            print $piece;
        print "\n" if EOL();
    }

    # finish up if needed
    print "\n" if EOL();
}

sub print_words_html {
	print '<ul>', "\n";
    foreach my $word (@selected_words) {
		print '<li>', $word, '</li>', "\n";
	}
	print '</ul>', "\n";
}


# Given a cell $orig_y,$orig_x that contains a letter that's somewhere in $word,
# try to place $word so that it passes through $orig_y,$orig_x. Return 1 on success.
# Global @letters contains letters of $word.
sub try_word_around {
    my $word = shift;
    my $orig_x = shift;
    my $orig_y = shift;
    my $size = shift;
    my $possible_directions = shift;
    my $direction;
    my $letter = $grid[$orig_y][$orig_x];
    my $index; # occurrence of the letter in the word
    my $done = 0;
    my @direction_choices = ();

            # For each occurrence of $letter in $word...
            for ($index = index($word, $letter); $index != -1 && !$done; $index = index($word, $letter, $index+1)) {
                        # Try all possible directions but don't commit to any of them.
                for ($direction = 0; $direction<$possible_directions; $direction++) {
                    my $x = $orig_x - ($index * $x_offset[$direction]);
                    my $y = $orig_y - ($index * $y_offset[$direction]);
                    my $error = 0;
            
                    foreach my $letter (@letters) {
                        if ($x < 0) {
                            $x=0;
                            $error = 1;
                        }
                        if ($x >= $size) {
                            $x=$size;
                            $error = 1;
                        }
                        if ($y < 0) {
                            $y=0;
                            $error = 1;
                        }
                        if ($y >= $size) {
                            $y=$size;
                            $error = 1;
                        }
                        if (!is_empty($x, $y)) { 
                            if ($grid[$y][$x] ne $letter)  {
                                $error = 1;
                            }
                        }
                        $x+= $x_offset[$direction];
                        $y+= $y_offset[$direction];
            
                    }
                    if (0 == $error) {
                        push @direction_choices, $direction;
                    } else {
                        next;
                    }
                }
                # OK, pick one of the directions that works for this word, if any,
                # and put the word there.
                if (0 < scalar @direction_choices ) {
                    print "Direction choices: " . scalar @direction_choices . "\n" if $debug;

                    my $rand_direction = @direction_choices[int(rand scalar @direction_choices)];
                    print "$rand_direction\n" if $debug;
            
                    my $x = $orig_x - ($index * $x_offset[$rand_direction]);
                    my $y = $orig_y - ($index * $y_offset[$rand_direction]);
                          # was: $word_x_starts[$words_placed] = $x;
                          # was: $word_y_starts[$words_placed] = $y;
                          # was: $word_dirs[$words_placed] = $rand_direction;
                          unshift(@word_x_starts, $x);
                          unshift(@word_y_starts, $y);
                          unshift(@word_dirs, $rand_direction);

                    foreach $letter (@letters) {
                        if (is_empty($x, $y)) { 
                                            $spaces_left--;
                            $grid[$y][$x] = $letter;
                        } elsif ($grid[$y][$x] eq $letter)  {
                                    $intersections++;            
                        } else {
                            die &print_grid;
                        }
                        $x+= $x_offset[$rand_direction];
                        $y+= $y_offset[$rand_direction];
                    }
                    $done = 1;
                }
            }
    return $done;
}

# Try to place $word starting at cell $x,$y.
# On success, place the word and return 1.
sub test_word_position {
    my $orig_x = shift;
    my $orig_y = shift;
    my $size = shift;
    my $possible_directions = shift;
    my $direction;
    my $done = 0;
    my @direction_choices = ();

    for (my $direction = 0; $direction < $possible_directions; $direction++) {
        my $x = $orig_x;
        my $y = $orig_y;
        my $error = 0;

        foreach my $letter (@letters) {
            if ($x <= 0) {
                $x=0;
                $error = 1;
            }
            if ($x >= $size) {
                $x=$size;
                $error = 1;
            }
            if ($y <= 0) {
                $y=0;
                $error = 1;
            }
            if ($y >= $size) {
                $y=$size;
                $error = 1;
            }
            if (!is_empty($x, $y)) { 
                if ($grid[$y][$x] ne $letter)  {
                    $error = 1;
                }
            }
            $x+= $x_offset[$direction];
            $y+= $y_offset[$direction];

        }
        if (0 == $error) {
            push @direction_choices, $direction;
        } else {
            next;
        }
    }
    if (0 < scalar @direction_choices ) {
        print "Direction choices: " . scalar @direction_choices . "\n" if $debug;
        my $x = $orig_x;
        my $y = $orig_y;
        my $rand_direction = @direction_choices[int(rand scalar @direction_choices)];
        print "$rand_direction\n" if $debug;
                          # was: $word_x_starts[$words_placed] = $x;
                          # was: $word_y_starts[$words_placed] = $y;
                          # was: $word_dirs[$words_placed] = $rand_direction;
                          unshift(@word_x_starts, $x);
                          unshift(@word_y_starts, $y);
                          unshift(@word_dirs, $rand_direction);

        foreach my $letter (@letters) {
            if (is_empty($x, $y)) { 
                                $spaces_left--;
                $grid[$y][$x] = $letter;
            } elsif ($grid[$y][$x] eq $letter)  {
                        $intersections++;            
            } else {
                die &print_grid;
            }
            $x+= $x_offset[$rand_direction];
            $y+= $y_offset[$rand_direction];
        }
        $done = 1;
    }
    return $done;
}

sub clear_grid {
    for (my $i=0; $i < $gridsize; $i++) {
        for (my $j=0; $j < $gridsize; $j++) {
            $grid[$i][$j] = '-';
        }
    }
}

# Uppercase, strip diacritics, etc.
# Thanks to http://www.ahinea.com/en/tech/accented-translate.html for help on this.
sub normalize {
    if ($no_normalize) {
        $_ = shift;
        return $_;
    }
    use Unicode::Normalize;
    $_ = NFD(shift);  # decompose (with compatibility mapping)
    s/[^\pL]//g; # strip diacritics, spaces, punctuation, and
             # anything that's not a letter
    # Replace positional forms with "normal" form, e.g. Greek small final
    # sigma with nonfinal sigma # I thought NFKD normalization was supposed
    # to accomplish this, but it doesn't seem to do it. If anybody knows
    # how to do this in a more general way, please let me know. 

    # Greek sigma; Hebrew kaf, mem, nun, peh, tsadeh 
    tr/\x{03C2}\x{05da}\x{05dd}\x{05df}\x{05e3}\x{05e5}/\x{03C3}\x{05db}\x{05de}\x{05e0}\x{05e4}\x{05e6}/;
    if ($lowercase) {
        $_ = lc $_ 
    } else {
        $_ = uc $_;
    }
    return $_;
}

# Check that no word can be found in the puzzle in two different places.
# If so, warn the user.
sub check_unique {
    my $ok = 1;
    foreach my $word (@selected_words) {
#        print "Checking unique solution for $word\n" if $debug;
        if (find_word($word) > 1) {
            print "Warning: $word appears more than once.\n";
            $ok = 0;
        }
    }
    return $ok;
}

# Search for $word in the grid. Return 0 if not found, 1 if it occurs exactly once,
# 2 if it occurs more than once.
sub find_word {
    my $word = shift;
    @letters = split(//, $word);
    my $occurrences = 0;
    for (my $i=0; $i < $gridsize; $i++) {
        for (my $j=0; $j < $gridsize; $j++) {
            if ($grid[$i][$j] eq $letters[0])  {
#                print "Looking at $i,$j\n" if $debug;

                for (my $dir = 0; $dir < $directions; $dir++) {
#                    print "Dir $dir\n" if $debug;
                    my $error = 0;
                    my $x = $j;
                    my $y = $i;
            
                    foreach my $letter (@letters) {
                        if ($x < 0 || $x >= $gridsize || $y < 0 || $y >= $gridsize || $grid[$y][$x] ne $letter)  {
                            $error = 1;
                            last;
                        }
                        $x += $x_offset[$dir];
                        $y += $y_offset[$dir];
                    }
                    if (!$error) {
                        $occurrences++;
                        if ($occurrences > 1) { return 2; }
                    }
                }
            }
        }
    }
    return $occurrences;
}

sub usage {
    print "Usage: $0 [OPTION] \n";
    print "Creates a word search puzzle.\n";
    print "\n";
    print " --size        Size of the grid (default=$gridsize).\n";
    print " --directions    Directions to place words (default=$directions).\n";
    print "        (Diagonals and reverse words = 8, No diagonals = 4,\n         No reverse words = 2)\n";
    print " --words    Number of words to select (default=$num_of_words)\n";
    print " --fillwithquote\n        Use last word of wordfile as a quote to fill in leftover spaces\n";
    print "        (Otherwise use random letters [the default])\n";
    print " --righttoleft    Fill in right-to-left (applies only when fillwithquote is true)\n";
    print " --lowercase    Change all letters to indicated case: upper (default),\n";
    print "        lower, or none (no change).\n";
    print " --checkunique    Check that each word is found only once in the grid\n";
    print "        (default=$checkunique).\n";
    print " --wordfile    Read words from a file instead of from default location.\n";
    print "        (Currently $wordfile)\n";
    print " --similarwords    Allow words that are similar to each other\n";
    print "        (default=$similar_words)\n";
    print " --minwordlength Minimum word length to check for similarity\n";
    print "        (default=$min_word_length)\n";
    print " --all        Use all words from the list of words provided.\n";
    print "         (DO NOT USE THIS WITH THE DEFAULT WORD LIST LOCATION!)\n";
    print " --nonormalize    Don't try to normliaze the input file\n";
    print "        (useful for number searches)\n";
    print " --nosolution    Don't display the solution.\n";
    print " --svg        Use SVG to display the solution \n        (ignored if --nosolution is used).\n"; 
    print " --nogrow    Don't grow the grid to find a solution.\n";
    print " --quick    Iterate one time through before trying new parameters.\n";
    print " --thorough    Iterate many more times through before trying new parameters.\n";
    print " --debug    Display debugging output.\n";    
    print " --version    Display the version number.\n";
    print " --help        Display this help file.\n";
    print "\nReport bugs to <craig\@decafbad.net>\n"
}

sub start_section_text {
}

sub end_section_text {
    print "\n";
}

sub print_heading_text {
	my ($heading) = @_;
    print $heading, ":\n";
}

sub start_grid_text {
}

sub end_grid_text {
}

sub start_row_text {
}

sub end_row_text {
	print "\n";
}

sub start_col_text {
}

sub end_col_text {
	print ' ';
}

sub print_header_text {
	print $title, "\n";
	print "\n";
}

sub print_footer_text {
}


sub print_heading_html {
	my ($heading) = @_;

	print '<h2>', $heading, '</h2>', "\n";
}

sub start_section_html {
	my ($id) = @_;
	printf '<section id="%s" class="%s">', $id, $id;
	print "\n";
}

sub end_section_html {
	print '</section>', "\n";
}

sub start_grid_html {
	print '<table>', "\n";
}

sub end_grid_html {
	print '</table>', "\n";
}

sub start_row_html {
	print '<tr>',"\n";
}

sub end_row_html {
	print '</tr>',"\n";
}

sub start_col_html {
	print '<td>';
}

sub end_col_html {
	print '</td>';
}

sub print_header_html {
print <<EOF
<html>
	<head>
		<title></title>
		<link rel="stylesheet" href="wordsearch.css">
	</head>

	<body>
	<h1>$title</h1>
	<button id="tog">Show Solution</button>
EOF
}

sub print_footer_html {
print <<EOF
	<script>
var toggleButton = document.getElementById("tog");
var solution = document.getElementById("solution");

toggleButton.addEventListener("click", function() {
  solution.classList.toggle("m-fadeIn");
});
	</script>

	</body>
</html>
EOF
}
