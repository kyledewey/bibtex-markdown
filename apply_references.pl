#!/usr/bin/perl

use BibTeX::Parser;
use IO::File;
use strict;

sub usage() {
    print "Takes the following params:\n";
    print "-A bibtex file\n";
    print "-Input markdown file, possibly with citations\n";
    print "-Output markdown filename\n";
}

# gets the bibtex entries from the given filename
sub bibtexEntries($) {
    my $filename = shift();
    my $fh = IO::File->new($filename) or die "Could not open bibtex file '$filename'";
    my $parser = BibTeX::Parser->new($fh);
    my @retval;
    my $numEntry = 1;
    while(my $entry = $parser->next) {
	if (!$entry->parse_ok) {
	    print "Error parsing bibtex entry #$numEntry: $entry->error\n";
	    exit(1);
	}
	push(@retval, $entry);
    }
    return @retval;
}

# Takes the name of the file to read from
sub linesFromFile($) {
    my $filename = shift();
    open(INPUT, "<$filename") or die "Could not open input file '$filename'";
    my @retval;
    while(my $line = <INPUT>) {
	chomp($line);
	push(@retval, $line);
    }
    close(INPUT);
    return @retval;
}

# takes the following:
# -Reference to an array of lines
# -Name of the file to write to
sub linesToFile($$) {
    my ($linesRef, $filename) = @_;
    open(OUTPUT, ">$filename") or die "Could not open output file '$filename'";
    foreach my $line (@$linesRef) {
	print OUTPUT "$line\n";
    }
    close(OUTPUT);
}

sub compareEntriesSameAuthorsPrefix($$) {
    my ($entry1, $entry2) = @_;
    my $title1 = $entry1->field('title');
    my $title2 = $entry2->field('title');
    if ($title1 && $title2) {
	my $compare = $title1 cmp $title2;
	if ($compare != 0) {
	    return $compare;
	} else {
	    # titles are equal - try for the year
	    my $year1 = $entry1->field('year');
	    my $year2 = $entry2->field('year');
	    if ($year1 && $year2) {
		return $year1 <=> $year2;
	    } elsif ($year1) {
		# year2 is undef; consider undef after
		return -1;
	    } else {
		# year1 is undef
		return 1;
	    }
	}
    } elsif ($title1) {
	return -1;
    } else {
	return 1;
    }
}

sub compareEntries($$) {
    my ($entry1, $entry2) = @_;
    my @authors1 = $entry1->author;
    my @authors2 = $entry2->author;
    my $index = 0;
    while($index < scalar(@authors1) &&
	  $index < scalar(@authors2)) {
	my $aString1 = authorString($authors1[$index]);
	my $aString2 = authorString($authors2[$index]);
	my $compare = $aString1 cmp $aString2;
	if ($compare != 0) {
	    return $compare;
	}
	$index++;
    }

    # leading authors were the same
    if ($index >= scalar(@authors1) &&
	$index >= scalar(@authors2)) {
	return compareEntriesSameAuthorsPrefix($entry1, $entry2);
    } elsif ($index >= scalar(@authors1)) {
	# second entry has more authors - put it after this one
	return -1;
    } else {
	# first entry has more authors
	return 1;
    }
}

sub entriesComparator {
    return compareEntries($a, $b);
}

# takes a bibtex author
sub authorString($) {
    my $author = shift();
    my $retval = $author->first;
    if ($author->von) {
	$retval .= " " . $author->von;
    }
    $retval .= " " . $author->last;
    if ($author->jr) {
	$retval .= " " . $author->jr;
    }
    return $retval;
}

sub authorsString(@) {
    my @authors = @_;
    if (scalar(@authors) == 0) {
	return '';
    } elsif (scalar(@authors) == 1) {
	return authorString($authors[0]);
    } elsif (scalar(@authors) == 2) {
	return authorString($authors[0]) . " and " . authorString($authors[1]);
    } else {
	my $first = shift(@authors);
	return authorString($first) . ", " . authorsString(@authors);
    }
}

# given a bibtex entry, it returns an appropriate string for the entry
sub bibtexEntryToString($) {
    my $entry = shift();
    my @authors = $entry->author;
    my $retval = authorsString(@authors);
    my $title = $entry->field('title');
    if ($title) {
	$retval .= ". " . $title . ".";
    }
    my $year = $entry->field('year');
    if ($year) {
	$retval .= " " . $year;
    }
    return $retval;
}

# takes the entry and which entry this is
sub bibtexEntryToMarkdown($$) {
    my ($entry, $whichEntry) = @_;
    my $asString = bibtexEntryToString($entry);
    my $id = htmlizeId($entry->key);
    return $whichEntry . ". <a id=\"$id\"></a>$asString";
}

# gets the citation keys used in the given lines
# returns a reference to a hash of keys used, where the values are undef
sub citationKeysInLines(@) {
    my @lines = @_;
    my %retval;
    foreach my $line (@lines) {
	foreach ($line =~ /\\cite\{(.*?)\}/g) {
	    $retval{$1} = undef;
	}
    }
    return \%retval;
}

# given an array of bibtex entries, returns a reference to a hash
# mapping bibtex entry keys to bibtex entries
sub citationMapping(@) {
    my @entries = @_;
    my %retval;
    foreach my $entry (@entries) {
	$retval{$entry->key} = $entry;
    }
    return \%retval;
}

# takes a bibtex entry
sub entryToReplacement($) {
    my $entry = shift();
    my @authors = $entry->author;
    my $author = $authors[0];
    my $text = "";
    if ($author->von) {
	$text .= $author->von . " ";
    }
    $text .= $author->last;
    if (scalar(@authors) > 1) {
	$text .= " et al.";
    }
    my $id = htmlizeId($entry->key);
    return "[$text](#$id)";
}

sub htmlizeId($) {
    my $id = shift();
    if ($id =~ /^[^A-Za-z]/) {
	$id = 'a' . $id;
    }
    while ($id =~ /^(.*)([^A-Za-z0-9\-_:\.])(.*)$/) {
	$id = $1 . ord($2) . $3;
    }
    return $id;
}

# takes the following:
# -Reference to a hash of citation keys used
# -Reference to a hash mapping citation keys to entries
# returns the following:
# -Reference to an array of entries used in their correct order
# -Reference to a hash of keys to what to replace them with in the text
sub intersectBibtexEntries($$) {
    my ($citationsUsedRef,
	$bibtexEntriesRef) = @_;
    my %replacements;
    my @unsortedUsed;
    foreach my $key (keys(%$citationsUsedRef)) {
	if (!exists($bibtexEntriesRef->{$key})) {
	    print "Internal failure.  No bibtex entry for '$key'";
	    exit(1);
	}
	push(@unsortedUsed, $bibtexEntriesRef->{$key});
    }
    my @sortedUsed = sort entriesComparator @unsortedUsed;
    foreach my $used (@sortedUsed) {
	$replacements{$used->key} = entryToReplacement($used);
    }
    return (\@sortedUsed, \%replacements);
}

# takes the following:
# -Reference to lines
# -Reference to a mapping of keys to what to replace them with
# replaces citations with what is listed to replace them with
sub replaceCitations($$) {
    my ($linesRef, $keysMappingRef) = @_;
    for(my $lineNum = 0; $lineNum < scalar(@$linesRef); $lineNum++) {
	while ($linesRef->[$lineNum] =~ /^(.*)\\cite\{(.*?)\}(.*)$/) {
	    $linesRef->[$lineNum] = $1 . $keysMappingRef->{$2} . $3;
	}
    }
}

# takes the following:
# -Reference to lines
# -Reference to a sorted array of bibtex entries
sub replaceOrAddReferences($$) {
    my ($linesRef, $sortedEntries) = @_;
    my $referencesStartLine;
    for(my $lineNum = 0; $lineNum < scalar(@$linesRef); $lineNum++) {
	if ($linesRef->[$lineNum] =~ /^## References\s*/) {
	    $referencesStartLine = $lineNum;
	    last;
	}
    }
    
    if ($referencesStartLine) {
	# remove it if it wasn't already there
	my $numToRemove = scalar(@$linesRef) - $referencesStartLine + 1;
	for(my $x = 0; $x < $numToRemove; $x++) {
	    pop(@$linesRef);
	}
    }

    # add in the reference section
    push(@$linesRef, '## References');
    my $whichEntry = 1;
    foreach my $entry (@$sortedEntries) {
	push(@$linesRef, bibtexEntryToMarkdown($entry, $whichEntry));
	$whichEntry++;
    }
}

    
# BEGIN MAIN CODE
if (scalar(@ARGV) != 3) {
    usage();
    exit(1);
}

my $bibtexFilename = shift();
my $markdownFilename = shift();
my $outputFilename = shift();

my @inputLines = linesFromFile($markdownFilename);
my @bibtexEntries = bibtexEntries($bibtexFilename);
my $bibtexMappingRef = citationMapping(@bibtexEntries);
my $citationKeysInLinesRef = citationKeysInLines(@inputLines);
my ($orderedEntriesRef,
    $replacementsRef) = intersectBibtexEntries($citationKeysInLinesRef,
					       $bibtexMappingRef);
replaceCitations(\@inputLines, $replacementsRef);
replaceOrAddReferences(\@inputLines, $orderedEntriesRef);
linesToFile(\@inputLines, $outputFilename);
