#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A join of two tables.

package Triceps::JoinTwo;
use Carp;

use strict;

# Options:
# unit - unit object
# name - name of this object (will be used to create the names of internal objects)
# leftTable - table object to join
# rightTable - table object to join
# leftIdxPath - array reference containing the path name of index type 
#    in the left table used for look-up,
#    index absolutely must be a Hash (leaf or not), not of any other kind
# rightIdxPath - array reference containing the path name of index type 
#    in the left table used for look-up,
#    index absolutely must be a Hash (leaf or not), not of any other kind;
#    the number and order of fields in left and right indexes must match
#    since indexes define the fields used for the join; the types of fields
#    don't have to match exactly since Perl will connvert them if possible
# leftFields (optional) - reference to array of patterns for left fields to pass through,
#    syntax as described in Triceps::Fields::filter(), if not defined then pass everything
# rightFields (optional) - reference to array of patterns for right fields to pass through,
#    syntax as described in Triceps::Fields::filter(), if not defined then pass everything
#    (which may results with the join-condition fields copied twice from both tables).
# type (optional) - one of: "inner" (default), "left", "right", "outer".
#    For correctness purposes, there are limitations on what outer joins
#    can be used with which indexes:
#        inner - either index may be leaf or non-leaf
#        left - right index must be leaf (i.e. a primary index, with 1 record per key)
#        right - left index must be leaf (i.e. a primary index, with 1 record per key)
#        outer - both indexes must be leaf (i.e. a primary index, with 1 record per key)
#    This can be overriden by setting simpleMinded => 1.
# simpleMinded (optional) - do not try to create the correct DELETE-INSERT sequence
#    for updates, just produce records with the same opcode as the incoming ones.
#    The data produced is outright garbage, this option is here is purely for
#    an entertainment value, to show, why it's garbage.
#    (default: 0)
#
#    XXX add ability to map the join condition fields from both source rows into the
#    same fields of the result, the joiner knowing how to handle this correctly.
sub new # (class, optionName => optionValue ...)
{
	my $class = shift;
	my $self = {};
	my $i;

	# the logic works by connecting the output of each table in a
	# LookupJoin of the other table

	&Triceps::Opt::parse($class, $self, {
			unit => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			leftTable => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
			rightTable => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
			leftIdxPath => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
			rightIdxPath => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
			leftFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			rightFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			type => [ "inner", undef ],
			simpleMinded => [ 0, undef ],
		}, @_);

	Carp::confess("Self-joins (the same table on both sides) are not supported") 
		if $self->{leftTable}->same($self->{rightTable});

	my ($leftLeft, $rightLeft);
	if ($self->{type} eq "inner") {
		$leftLeft = 0;
		$rightLeft = 0;
	} elsif ($self->{type} eq "left") {
		$leftLeft = 1;
		$rightLeft = 0;
	} elsif ($self->{type} eq "right") {
		$leftLeft = 0;
		$rightLeft = 1;
	} elsif ($self->{type} eq "outer") {
		$leftLeft = 1;
		$rightLeft = 1;
	} else {
		Carp::confess("Unknown value '" . $self->{type} . "' of option 'type', must be one of inner|left|right|outer");
	}

	$self->{leftRowType} = $self->{leftTable}->getRowType();
	$self->{rightRowType} = $self->{rightTable}->getRowType();

	my @leftdef = $self->{leftRowType}->getdef();
	my %leftmap = $self->{leftRowType}->getFieldMapping();
	my @leftfld = $self->{leftRowType}->getFieldNames();

	my @rightdef = $self->{rightRowType}->getdef();
	my %rightmap = $self->{rightRowType}->getFieldMapping();
	my @rightfld = $self->{rightRowType}->getFieldNames();

	# compare the index definitions, check that the fields match
	for my $side ( ("left", "right") ) {
		$self->{"${side}IdxType"} = $self->{"${side}Table"}->getType()->findIndexPath(@{$self->{"${side}IdxPath"}});
		# would already confess if the index is not found
		#Carp::confess("The $side table does not have a top-level index '" . $self->{"${side}Index"} . "' for joining")
		#	unless defined $self->{"${side}IdxType"};
		my $ixid  = $self->{"${side}IdxType"}->getIndexId();
		Carp::confess("The $side index '" . $self->{"${side}Index"} . "' is of kind '" . &Triceps::indexIdString($ixid) . "', not IT_HASHED as required")
			unless ($ixid == &Triceps::IT_HASHED);

		if (!$self->{simpleMinded}) {
			my @subs = $self->{"${side}IdxType"}->getSubIndexes();
			if ($#subs >= 0 # has sub-indexes, a non-leaf index
			&& ($self->{type} ne "inner" && $self->{type} ne $side) ) {
				Carp::confess("The $side index is non-leaf, not supported with type '" . $self->{type} . "', use option simpleMinded=>1 to override")
			}
		}
	}
	my @leftkeys = $self->{leftIdxType}->getKey();
	my @rightkeys = $self->{rightIdxType}->getKey();
	Carp::confess("The count of fields in left and right indexes doesnt match\n  left:  (" 
			. join(", ", @leftkeys) . ")\n  right: (" . join(", ", @rightkeys) . ")\n  ")
		unless ($#leftkeys == $#rightkeys);

	my (@leftby, @rightby); # build the "by" specifications for LookupJoin
	for ($i = 0; $i <= $#leftkeys; $i++) { # check that the array-ness matches
		push @leftby, $leftkeys[$i], $rightkeys[$i];
		push @rightby, $rightkeys[$i], $leftkeys[$i];

		my $leftType = $leftdef[ $leftmap{$leftkeys[$i]}*2 + 1];
		my $rightType = $rightdef[ $rightmap{$rightkeys[$i]}*2 + 1];
		# for Perl representation, uint8[] is the same as string, so treat it as such
		$leftType =~ s/uint8\[\]/string/;
		$rightType =~ s/uint8\[\]/string/;
		Carp::confess("Mismatched array and scalar fields in key: left " 
				. $leftkeys[$i] . " " . $leftdef[ $leftmap{$leftkeys[$i]}*2 + 1] . ", right "
				. $rightkeys[$i] . " " . $rightdef[ $rightmap{$rightkeys[$i]}*2 + 1])
			if (($leftType =~ /\[\]$/) ^ ($rightType =~ /\[\]$/));
	}

	# now create the LookupJoins
	$self->{leftLookup} = Triceps::LookupJoin->new(
		unit => $self->{unit},
		name => $self->{name} . ".leftLookup",
		leftRowType => $self->{leftRowType},
		rightTable => $self->{rightTable},
		rightIdxPath => $self->{rightIdxPath},
		leftFields => $self->{leftFields},
		rightFields => $self->{rightFields},
		fieldsLeftFirst => 1,
		by => \@leftby,
		isLeft => $leftLeft,
		automatic => 1,
		oppositeOuter => ($rightLeft && !$self->{simpleMinded}),
	);
	$self->{rightLookup} = Triceps::LookupJoin->new(
		unit => $self->{unit},
		name => $self->{name} . ".rightLookup",
		leftRowType => $self->{rightRowType},
		rightTable => $self->{leftTable},
		rightIdxPath => $self->{leftIdxPath},
		leftFields => $self->{rightFields},
		rightFields => $self->{leftFields},
		fieldsLeftFirst => 0,
		by => \@rightby,
		isLeft => $rightLeft,
		automatic => 1,
		oppositeOuter => ($leftLeft && !$self->{simpleMinded}),
	);

	# create the output label
	$self->{outputLabel} = $self->{unit}->makeDummyLabel($self->{leftLookup}->getResultRowType(), $self->{name} . ".out");
	Carp::confess("$!") unless (ref $self->{outputLabel} eq "Triceps::Label");

	# and connect them together
	$self->{leftTable}->getOutputLabel()->chain($self->{leftLookup}->getInputLabel());
	$self->{rightTable}->getOutputLabel()->chain($self->{rightLookup}->getInputLabel());
	$self->{leftLookup}->getOutputLabel()->chain($self->{outputLabel});
	$self->{rightLookup}->getOutputLabel()->chain($self->{outputLabel});

	bless $self, $class;
	return $self;
}

sub getResultRowType # (self)
{
	my $self = shift;
	return $self->{leftLookup}->getResultRowType();
}

sub getOutputLabel # (self)
{
	my $self = shift;
	return $self->{outputLabel};
}

# XXX for production add more getter methods

1;
