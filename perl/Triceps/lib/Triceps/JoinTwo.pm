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
# name - name of this object (will be used to create the names of internal objects)
# leftTable - table object to join (both tables must be of the same unit)
# rightTable - table object to join
# leftFromLabel (optional) - the label from which to react to the rows on the
#    left side (default: leftTable's output label), can be used to filter
#    out some of the input. THIS IS DANGEROUS! To preserve consistency, always
#    filter by key field(s) only, and the same condition on the left and right.
# rightFromLabel (optional) - the label from which to react to the rows on the
#    right side (default: rightTable's output label), can be used to filter
#    out some of the input. THIS IS DANGEROUS! To preserve consistency, always
#    filter by key field(s) only, and the same condition on the left and right.
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
# fieldsLeftFirst (optional) - flag: in the resulting records put the fields from
#    the left record first, then from right record, or if 0, then opposite. (default:1)
# fieldsUniqKey (optional) - one of "none", "manual", "left", "right", "first" (default)
#    Controls the automatic prevention of dupplication of the key fields, which
#    by definition have the same values in both the left and right rows.
#    This is done by manipulating the left/rightFields option: one side is left
#    unchanged, and thus lets the user pass the key fields as usual, while
#    the other side gets "!key" specs prepended to the front of it for each key
#    fields, thus removing the duplication.
#    The flag fieldsMirrorKey of the underlying LookupJoins is always set to 1,
#    except in the "none" mode.
#        none - do not change either of the left/rightFields, and do not enable
#            the key mirroring at all
#        manual - do not change either of the left/rightFields, leave the full control to the user.
#        left - do not change leftFields (and thus pass the key in there), remove the keys from rightFields
#        right - do not change rightFields (and thus pass the key in there), remove the keys from leftFields
#        first - do not change whatever side goes first (and thus pass the key in there), 
#            remove the keys from the other side
# type (optional) - one of: "inner" (default), "left", "right", "outer".
#    For correctness purposes, there are limitations on what outer joins
#    can be used with which indexes:
#        inner - either index may be leaf or non-leaf
#        left - right index must be leaf (i.e. a primary index, with 1 record per key)
#        right - left index must be leaf (i.e. a primary index, with 1 record per key)
#        outer - both indexes must be leaf (i.e. a primary index, with 1 record per key)
#    This can be overriden by setting simpleMinded => 1.
# leftSaveJoinerTo (optional, ref to a scalar) - where to save a copy of the joiner function
#    source code for the left side
# rightSaveJoinerTo (optional, ref to a scalar) - where to save a copy of the joiner function
#    source code for the right side
# simpleMinded (optional) - do not try to create the correct DELETE-INSERT sequence
#    for updates, just produce records with the same opcode as the incoming ones.
#    The data produced is outright garbage, this option is here is purely for
#    an entertainment value, to show, why it's garbage.
#    (default: 0)
#
#    XXX add byPattern
sub new # (class, optionName => optionValue ...)
{
	my $class = shift;
	my $self = {};
	my $i;

	# the logic works by connecting the output of each table in a
	# LookupJoin of the other table

	&Triceps::Opt::parse($class, $self, {
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			leftTable => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
			rightTable => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
			leftFromLabel => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Label"); } ],
			rightFromLabel => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Label"); } ],
			leftIdxPath => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
			rightIdxPath => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
			leftFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			rightFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			fieldsLeftFirst => [ 1, undef ],
			fieldsUniqKey => [ "first", undef ],
			type => [ "inner", undef ],
			leftSaveJoinerTo => [ undef, sub { &Triceps::Opt::ck_refscalar(@_) } ],
			rightSaveJoinerTo => [ undef, sub { &Triceps::Opt::ck_refscalar(@_) } ],
			simpleMinded => [ 0, undef ],
		}, @_);

	Carp::confess("Self-joins (the same table on both sides) are not supported") 
		if $self->{leftTable}->same($self->{rightTable});

	$self->{unit} = $self->{leftTable}->getUnit();
	my $rightUnit = $self->{rightTable}->getUnit();
	Carp::confess("Both tables must have the same unit, got '" . $self->{unit}->getName() . "' and '" . $rightUnit->getName() . "'") 
		unless($self->{unit}->same($rightUnit));

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

	# find the feed labels, compare the index definitions, check that the fields match
	for my $side ( ("left", "right") ) {
		if (defined $self->{"${side}FromLabel"}) {
			Carp::confess("The ${side}FromLabel unit does not match ${side}Table, '" 
					. $self->{"${side}FromLabel"}->getUnit()->getName() . "' vs '" . $self->{unit}->getName() . "'")
				unless $self->{unit}->same($self->{"${side}FromLabel"}->getUnit());
			Carp::confess("The ${side}FromLabel row type does not match ${side}Table,\nin label:\n  " 
					. $self->{"${side}FromLabel"}->getType()->print("  ") . "\nin table:\n  " 
					. $self->{"${side}Table"}->getRowType()->print("  "))
				unless $self->{"${side}Table"}->getRowType()->match($self->{"${side}FromLabel"}->getType());
		} else {
			$self->{"${side}FromLabel"} = $self->{"${side}Table"}->getOutputLabel();
		}

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
	my(@leftkeys, @rightkeys);
	($self->{leftIdxType}, @leftkeys) = $self->{leftTable}->getType()->findIndexKeyPath(@{$self->{leftIdxPath}});
	($self->{rightIdxType}, @rightkeys) = $self->{rightTable}->getType()->findIndexKeyPath(@{$self->{rightIdxPath}});
	Carp::confess("The count of key fields in left and right indexes doesnt match\n  left:  (" 
			. join(", ", @leftkeys) . ")\n  right: (" . join(", ", @rightkeys) . ")\n  ")
		unless ($#leftkeys == $#rightkeys);

	my (@leftby, @rightby); # build the "by" specifications for LookupJoin
	for ($i = 0; $i <= $#leftkeys; $i++) { # check that the array-ness matches
		push @leftby, $leftkeys[$i], $rightkeys[$i];
		push @rightby, $rightkeys[$i], $leftkeys[$i];

		my $leftType = $leftdef[ $leftmap{$leftkeys[$i]}*2 + 1];
		my $rightType = $rightdef[ $rightmap{$rightkeys[$i]}*2 + 1];
		my $leftArr = &Triceps::Fields::isArrayType($leftType);
		my $rightArr = &Triceps::Fields::isArrayType($rightType);

		Carp::confess("Mismatched array and scalar fields in key: left " 
				. $leftkeys[$i] . " " . $leftType . ", right "
				. $rightkeys[$i] . " " . $rightType)
			unless ($leftArr == $rightArr);
	}

	my $fieldsMirrorKey = 1;
	my $uniq = $self->{fieldsUniqKey};
	if ($uniq eq "first") {
		$uniq = $self->{fieldsLeftFirst} ? "left" : "right";
	}
	if ($uniq eq "none") {
		$fieldsMirrorKey = 0;
	} elsif ($uniq eq "manual") {
		# nothing to do
	} elsif ($uniq =~ /^(left|right)$/) {
		my($side, @keys);
		if ($uniq eq "left") {
			$side = "right";
			@keys = @rightkeys;
		} else {
			$side = "left";
			@keys = @leftkeys;
		}
		if (!defined $self->{"${side}Fields"}) {
			$self->{"${side}Fields"} = [ ".*" ]; # the implicit pass-all
		}
		unshift(@{$self->{"${side}Fields"}}, map("!$_", @keys) );
	} else {
		Carp::confess("Unknown value '" . $self->{fieldsUniqKey} . "' of option 'fieldsUniqKey', must be one of none|manual|left|right|first");
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
		fieldsLeftFirst => $self->{fieldsLeftFirst},
		fieldsMirrorKey => $fieldsMirrorKey,
		by => \@leftby,
		isLeft => $leftLeft,
		automatic => 1,
		oppositeOuter => ($rightLeft && !$self->{simpleMinded}),
		saveJoinerTo => $self->{leftSaveJoinerTo},
	);
	$self->{rightLookup} = Triceps::LookupJoin->new(
		unit => $self->{unit},
		name => $self->{name} . ".rightLookup",
		leftRowType => $self->{rightRowType},
		rightTable => $self->{leftTable},
		rightIdxPath => $self->{leftIdxPath},
		leftFields => $self->{rightFields},
		rightFields => $self->{leftFields},
		fieldsLeftFirst => !$self->{fieldsLeftFirst},
		fieldsMirrorKey => $fieldsMirrorKey,
		by => \@rightby,
		isLeft => $rightLeft,
		automatic => 1,
		oppositeOuter => ($leftLeft && !$self->{simpleMinded}),
		saveJoinerTo => $self->{rightSaveJoinerTo},
	);

	# create the output label
	$self->{outputLabel} = $self->{unit}->makeDummyLabel($self->{leftLookup}->getResultRowType(), $self->{name} . ".out");
	Carp::confess("$!") unless (ref $self->{outputLabel} eq "Triceps::Label");

	# and connect them together
	$self->{leftFromLabel}->chain($self->{leftLookup}->getInputLabel());
	$self->{rightFromLabel}->chain($self->{rightLookup}->getInputLabel());
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
