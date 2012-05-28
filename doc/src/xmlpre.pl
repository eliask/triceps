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

	# this is specific to the Triceps examples
	$tl =~ s/\&send\b/print/g;
	$tl =~ s/\&readLine\b/<STDIN>/g;
	
	$tl =~ s/\&/\&amp;/g;
	$tl =~ s/</\&lt;/g;
	$tl =~ s/>/\&gt;/g;
	$tl =~ s/"/\&quot;/g;

	return $tl;
}


my $pre = 0;
my $lf = ''; # used to drop the extra LFs from inside <pre>
while(<STDIN>) {
	if ($pre) {
		if (/^<\/pre>\s*$/) {
			$pre = 0;
			print "</programlisting>\n";
		} else {
			chomp;
			print $lf, &xmlify($_);
			$lf = "\n";
		}
	} else {
		if (/^<pre>\s*$/) {
			# start of the multi-line block
			$pre = 1;
			$lf = '';
			print "<programlisting>";
		} else {
			# handle the inline blocks
			s/<pre>(.*?)<\/pre>/'<computeroutput>' . &xmlify($1) . '<\/computeroutput>'/ge;
			print;
		}
	}
}
