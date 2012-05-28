#!/usr/bin/perl
#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Format the plain text inside <pre> to look like XML and replace
# the tag with <programlisting>.
# Filters from stdin to stdout.

use strict;

sub xmlify # (text_line)
{
	my $tl = shift;

	# in XML form set tabs to 2 chars to reduce width
	$tl =~ s/\t/  /g;
	$tl =~ s/ +$//;
	
	$tl =~ s/\&/\&amp;/g;
	$tl =~ s/</\&lt;/g;
	$tl =~ s/>/\&gt;/g;
	$tl =~ s/"/\&quot;/g;

	return $tl;
}


# the flags $comment and $pre are mutually exclusive, <pre> inside
# the comments get ignored
my $comment = 0;
my $pre = 0;
my $lf = ''; # used to drop the extra LFs from inside <pre>
while(<STDIN>) {
	while (1) {
		if ($comment) {
			if (s/^(.*?-->)//) {
				print $1;
				$comment = 0;
			} else {
				print;
				last;
			}
		} 
		if ($pre) {
			if (s/^(.*?)<\/pre>//) {
				if ($1 ne '') {
					print $lf, &xmlify($1);
				} # otherwise skip the line feed
				print "</programlisting>";
				$pre = 0;
			} else {
				my $n = chomp;
				print $lf, &xmlify($_);
				if ($n) {
					$lf = "\n";
				} else {
					$lf = '';
				}
				last;
			}
		}
		if (/^(.*?)<(pre>|--)/) {
			print $1;
		} else {
			print;
			last;
		}
	}
}
