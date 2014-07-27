#
# (C) Copyright 2011-2014 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The parsing of brace-quoted lines.

package Triceps::Code;

sub CLONE_SKIP { 1; }

our $VERSION = 'v2.0.0';

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	compile
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

use Carp;

# Compile the code in either of Triceps-standard representations.
# Receives a code reference or a string.
# If the argument is an undef or a code reference, returns it unchanged
# (if the code is mandatory, checking it for undef is caller's responsibility).
# If the argument is a string, encloses it in "sub { ... }"
# and compiles. Either way, the result will be a code reference.
# Confesses on the compilation errors. The code description is used
# in the confession message.
sub compile # ( $code_ref_or_string, $optional_code_description )
{
	no warnings 'all'; # shut up the warnings from eval
	return $_[0] if (!defined $_[0] || ref $_[0] eq 'CODE');
	my $descr = $_[1] ? $_[1] : "Code snippet";
	
	if (ref \$_[0] ne 'SCALAR') {
		Carp::confess("$descr: code must be a source code string or a reference to Perl function");
	}

	my $src = "sub {\n" . $_[0] . "\n}\n";
	my $code = eval $src;

	if (!$code) {
		# $@ alerady includes \n, so don't add another one after it
		Carp::confess(
			"$descr: failed to compile the source code\n"
			. "Compilation error: $@The source code was:\n$src");
	}

	# XXX This is a cryptic message in case if the user gets something very
	# wrong with the brace balance. But it matches the message from PerlCallback.
	if (ref $code ne 'CODE') {
		Carp::confess("$descr: code must be a source code string or a reference to Perl function");
	}
	return $code
}
