#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The parsing of brace-quoted lines.

package Triceps::X::Braced;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	raw_split_braced split_braced
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

1;

