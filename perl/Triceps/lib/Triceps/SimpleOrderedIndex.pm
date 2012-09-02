#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A simple index with ordering by fields.

package Triceps::SimpleOrderedIndex;

our $VERSION = 'v1.0.1';

use Carp;

our @ISA = qw(Triceps::IndexType);

# Create a new ordered index. The order is specified
# as pairs of (fieldName, direction) where direction is a string
# "ASC" or "DESC".
sub new # ($class, $fieldName => $direction...)
{
	my $class = shift;
	my @args = @_; # save a copy

	# build a descriptive sortName
	my $sortName = 'SimpleOrder ';
	while ($#_ >= 0) {
		my $fld = shift;
		my $dir = shift;
		$sortName .= quotemeta($fld) . ' ' . quotemeta($dir) . ', ';
	}

	$self = Triceps::IndexType->newPerlSorted(
		$sortName, \&init, undef, @args
	) or confess "$!";
	bless $self, $class;
	return $self;
}

# The initialization function that actually parses the args.
# XXX should use a locale-aware comparison for string fields, plain for uint[]
# XXX does not support the array fields yet
# XXX a NULL field is considered the same as a 0 or empty string
sub init # ($tabt, $idxt, $rowt, @args)
{
	my ($tabt, $idxt, $rowt, @args) = @_;
	my %def = $rowt->getdef(); # the field definition
	my $errors; # collect as many errors as possible
	my $compare = "sub {\n"; # the generated comparison function
	my $connector = "return"; # what goes between the comparison operators

	while ($#args >= 0) {
		my $f = shift @args;
		my $dir = uc(shift @args);

		my ($left, $right); # order the operands depending on sorting direction
		if ($dir eq "ASC") {
			$left = 0; $right = 1;
		} elsif ($dir eq "DESC") {
			$left = 1; $right = 0;
		} else {
			$errors .= "unknown direction '$dir' for field '$f', use 'ASC' or 'DESC'\n";
			# keep going, may find more errors
		}
	
		my $type = $def{$f};
		if (!defined $type) {
			$errors .= "no field '$f' in the row type\n";
			next;
		}

		my $cmp = "<=>"; # the comparison operator
		if ($type eq "string"
		|| $type =~ /^uint8.*/) {
			$cmp = "cmp"; # string version
		} elsif($type =~ /\]$/) {
			$errors .= "can not order by the field '$f', it has an array type '$type', not supported yet\n";
			next;
		}

		my $getter = "->get(\"" . quotemeta($f) . "\")";

		$compare .= "  $connector \$_[$left]$getter $cmp \$_[$right]$getter\n";

		$connector = "||";
	}

	$compare .= "  ;\n";
	$compare .= "}";

	if (defined $errors) {
		# help with diagnostics, append the row type to the error listing
		$errors .= "the row type is:\n";
		$errors .= $rowt->print();
	} else {
		# compile the comparison
		#print STDERR "DEBUG Triceps::SimpleOrderedIndex::init: comparison function:\n$compare\n";
		my $cmpfunc = eval $compare 
			or return "Triceps::SimpleOrderedIndex::init: internal error when compiling the compare function:\n"
				. "$@\n"
				. "The generated comparator was:\n"
				. $compare;
		$idxt->setComparator($cmpfunc)
			or return "Triceps::SimpleOrderedIndex::init: internal error: can not set the compare function:\n"
			. "$!\n";
	}
	return $errors;
}

1;
