#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The parsing of brace-quoted lines.

package Triceps::X::Braced;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	raw_split_braced split_braced bunquote
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

# The magic of Perl REs is that they allow you to define even
# the context-free languages. This one splits off the first
# space-delimited and optionally brace-enquoted element from the line,
# with the brace nesting supported.
our $re_first = qr/^
	\s*+
	(
		(?:
			[^\s\\{}]
		|
			\\.
		)++
	|
		(\{
			(?:
				(?> \\. )
			|
				[^{}\\]++
			|
				(?-1)
			)*+
		\})
	)
	\s*+
/x;

# Will consume the original string; if anything is left then
# the braces were not balanced. The enquoting braces are left in.
sub raw_split_braced # (string)
{
	my @s;
	while($_[0] =~ s/$re_first//) {
		push @s, $1;
	}
	return @s;
}

# Will consume the original string; if anything is left then
# the braces were not balanced. The enquoting braces (the outermost
# layer) are removed. The backslashes are not substituted.
sub split_braced # (string)
{
	my @s;
	my $f;
	while($_[0] =~ s/$re_first//) {
		$f = $1;
		$f =~ s/^\{(.*)\}$/$1/;
		push @s, $f;
	}
	return @s;
}

# Per the syntax of the acceptable inputs for this module, the
# strings are quoted only once, and then they can be nested in braces
# any amount of times. On parsing back, you can split the nested
# braces any amount of times, and finally when you're ready to use
# a string, you need to unquote it once, to interpret any backslash escapes.
# This function interprets all the normal Perl substitutions.
sub bunquote # (string)
{
	my $s = shift;
	# This escapes special symbols that haven't been escaped yet
	# (i.e. these preceded by an even number of backslashes).
	# The quotes are tricky because they are not special characters
	# per the braced syntax and don't need to be escaped, but when
	# the string is passe to Perl for interpretation, the quotes are
	# special and need to be escaped. The same applies to the dollar
	# signs, and pretty much any non-word symbol (except for the
	# backslash itself).
	$s =~ s/(?<!\\)(?:\\\\)*\K[^\w\\]/\\$&/g;;

	# And this substitutes all the Perl escapes.
	eval "\"$s\"";
}

1;

