#
# (C) Copyright 2011-2013 Sergey A. Babkin.
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
	return $_[0] if (!defined $_[0] || ref $_[0]);
	my $code = eval "sub { " . $_[0] . " }";
	return $code if $code;
	my $descr = $_[1] ? $_[1] : "the code snippet";
	# $@ alerady includes \n, so don't add another one after it
	Carp::confess "Failed to compile $descr: $@Code: ---\n" . $_[0] . "\n---\n";
}
