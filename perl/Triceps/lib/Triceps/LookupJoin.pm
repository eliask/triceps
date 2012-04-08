#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A join by performing a look-up in a table (like "stream-to-window" in CCL).

package Triceps::LookupJoin;
use Carp;

# Options:
# unit - unit object
# name - name of this object (will be used to create the names of internal objects)
# leftRowType - type of the rows that will be used for lookup
# rightTable - table object where to do the look-ups
# rightIndex (optional) - name of index type in table used for look-up (default: first Hash),
#    index absolutely must be a Hash (leaf or not), not of any other kind
# leftFields (optional) - reference to array of patterns for left fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
# rightFields (optional) - reference to array of patterns for right fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
#    (which is probably a bad idea since it would include duplicate fields from the 
#    index, so override it)
# fieldsLeftFirst (optional) - flag: in the resulting records put the fields from
#    the left record first, then from right record, or if 0, then opposite. (default:1)
# by - reference to array, containing pairs of field names used for look-up,
#    [ leftFld1, rightFld1, leftFld2, rightFld2, ... ]
#    XXX production version should allow an arbitrary expression on the left?
# isLeft (optional) - 1 for left join, 0 for full join (default: 1)
# limitOne (optional) - 1 to return no more than one record, 0 otherwise (default: 0)
sub new # (class, optionName => optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
			unit => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			leftRowType => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::RowType") } ],
			rightTable => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
			rightIndex => [ undef, sub { &Triceps::Opt::ck_ref(@_, "") } ], # a plain string, not a ref
			leftFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			rightFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			fieldsLeftFirst => [ 1, undef ],
			by => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			isLeft => [ 1, undef ],
			limitOne => [ 0, undef ],
		}, @_);

	$self->{rightRowType} = $self->{rightTable}->getRowType();

	my @leftdef = $self->{leftRowType}->getdef();
	my %leftmap = $self->{leftRowType}->getFieldMapping();
	my @leftfld = $self->{leftRowType}->getFieldNames();

	my @rightdef = $self->{rightRowType}->getdef();
	my %rightmap = $self->{rightRowType}->getFieldMapping();
	my @rightfld = $self->{rightRowType}->getFieldNames();

	# XXX use getKey() to check that the "by" keys match the
	# keys of the index
	# XXX also in production should check the matching []-ness of fields

	# Generate the join function with arguments:
	# @param self - this object
	# @param row - row argument
	# @return - an array of joined rows
	my $genjoin = '
		sub  # ($self, $row)
		{
			my ($self, $row) = @_;

			#print STDERR "DEBUGX LookupJoin " . $self->{name} . " in: ", $row->printP(), "\n";

			my @leftdata = $row->toArray();
		';

	# create the look-up row (and check that "by" contains the correct field names)
	$genjoin .= '
			my $lookuprow = $self->{rightRowType}->makeRowHash(
				';
	my @cpby = @{$self->{by}};
	while ($#cpby >= 0) {
		my $lf = shift @cpby;
		my $rt = shift @cpby;
		Carp::confess("Option 'by' contains an unknown left-side field '$lf'")
			unless defined $leftmap{$lf};
		Carp::confess("Option 'by' contains an unknown right-side field '$rt'")
			unless defined $rightmap{$rt};
		$genjoin .= $rt . ' => $leftdata[' . $leftmap{$lf} . "],\n\t\t\t\t";
	}
	$genjoin .= ");\n\t\t\t";

	# translate the index
	if (defined $self->{rightIndex}) {
		$self->{rightIdxType} = $self->{rightTable}->getType()->findSubIndex($self->{rightIndex});
		Carp::confess("The table does not have a top-level index '" . $self->{rightIndex} . "' for joining")
			unless defined $self->{rightIdxType};
		my $ixid  = $self->{rightIdxType}->getIndexId();
		Carp::confess("The index '" . $self->{rightIndex} . "' is of kind '" . &Triceps::indexIdString($ixid) . "', not IT_HASHED as required")
			unless ($ixid == &Triceps::IT_HASHED);
	} else {
		$self->{rightIdxType} = $self->{rightTable}->findSubIndexById(&Triceps::IT_HASHED);
		Carp::confess("The table does not have a top-level Hash index for joining")
			unless defined $self->{rightIdxType};
	}
	if (!$self->{limitOne}) { # would need a sub-index for iteration
		my @subs = $self->{rightIdxType}->getSubIndexes();
		if ($#subs < 0) { # no sub-indexes, so guaranteed to match one record
			#print STDERR "DEBUG auto-deducing limitOne=1 subs=(", join(", ", @subs), ")\n";
			$self->{limitOne} = 1;
		} else {
			$self->{iterIdxType} = $subs[1]; # first index type object, they go in (name => type) pairs
			# (all sub-indexes are equivalent for our purpose, just pick first)
		}
	}

	##########################################################################
	# build the code that will produce one result record by combining
	# @leftdata and @rightdata into @resdata;

	my $genresdata .= '
				my @resdata = (';
	my @resultdef;
	my %resultmap; 
	my @resultfld;
	
	# reference the variables for access by left/right iterator
	my %choice = (
		leftdef => \@leftdef,
		leftmap => \%leftmap,
		leftfld => \@leftfld,
		rightdef => \@rightdef,
		rightmap => \%rightmap,
		rightfld => \@rightfld,
	);
	my @order = ($self->{fieldsLeftFirst} ? ("left", "right") : ("right", "left"));
	#print STDERR "DEBUG order is ", $self->{fieldsLeftFirst}, ": (", join(", ", @order), ")\n";
	for my $side (@order) {
		my $orig = $choice{"${side}fld"};
		my @trans = &filterFields($orig, $self->{"${side}Fields"});
		my $smap = $choice{"${side}map"};
		for ($i = 0; $i <= $#trans; $i++) {
			my $f = $trans[$i];
			#print STDERR "DEBUG ${side} [$i] is '" . (defined $f? $f : '-undef-') . "'\n";
			next unless defined $f;
			if (exists $resultmap{$f}) {
				Carp::confess("A duplicate field '$f' is produced from  ${side}-side field '"
					. $orig->[$i] . "'; the preceding fields are: (" . join(", ", @resultfld) . ")" )
			}
			my $index = $smap->{$orig->[$i]};
			#print STDERR "DEBUG   index=$index smap=(" . join(", ", %$smap) . ")\n";
			push @resultdef, $f, $choice{"${side}def"}->[$index*2 + 1];
			push @resultfld, $f;
			$resultmap{$f} = $#resultfld; # fix the index
			$genresdata .= '$' . $side . 'data[' . $index . "],\n\t\t\t\t";
		}
	}
	$genresdata .= ");";
	$genresdata .= '
				push @result, $self->{resultRowType}->makeRowArray(@resdata);
				#print STDERR "DEBUGX " . $self->{name} . " +out: ", $result[$#result]->printP(), "\n";';

	# end of result record
	##########################################################################

	# do the look-up
	$genjoin .= '
			#print STDERR "DEBUGX " . $self->{name} . " lookup: ", $lookuprow->printP(), "\n";
			my $rh = $self->{rightTable}->findIdx($self->{rightIdxType}, $lookuprow);
			Carp::confess("$!") unless defined $rh;
		';
	$genjoin .= '
			my @rightdata; # fields from the right side, defaults to all-undef, if no data found
			my @result; # the result rows will be collected here
		';
	if ($self->{limitOne}) { # an optimized version that returns no more than one row
		if (! $self->{isLeft}) {
			# a shortcut for full join if nothing is found
			$genjoin .= '
			return () if $rh->isNull();
			#print STDERR "DEBUGX " . $self->{name} . " found data: " . $rh->getRow()->printP() . "\n";
			@rightdata = $rh->getRow()->toArray();
';
		} else {
			$genjoin .= '
			if (!$rh->isNull()) {
				#print STDERR "DEBUGX " . $self->{name} . " found data: " . $rh->getRow()->printP() . "\n";
				@rightdata = $rh->getRow()->toArray();
			}
';
		}
		$genjoin .= $genresdata;
	} else {
		$genjoin .= '
			if ($rh->isNull()) {
				#print STDERR "DEBUGX " . $self->{name} . " found NULL\n";
'; 
		if ($self->{isLeft}) {
			$genjoin .= $genresdata;
		} else {
			$genjoin .= '
				return ();';
		}

		$genjoin .= '
			} else {
				#print STDERR "DEBUGX " . $self->{name} . " found data: " . $rh->getRow()->printP() . "\n";
				my $endrh = $self->{rightTable}->nextGroupIdx($self->{iterIdxType}, $rh);
				for (; !$rh->same($endrh); $rh = $self->{rightTable}->nextIdx($self->{rightIdxType}, $rh)) {
					@rightdata = $rh->getRow()->toArray();
' . $genresdata . '
				}
			}';
	}

	$genjoin .= '
			return @result;
		}';

	#print STDERR "DEBUG $genjoin\n";

	undef $@;
	eval "\$self->{joiner} = $genjoin;"; # compile!
	Carp::confess("Internal error: LookupJoin failed to compile the joiner function:\n$@\n")
		if $@;

	# now create the result row type
	#print STDERR "DEBUG result type def = (", join(", ", @resultdef), ")\n"; # DEBUG
	$self->{resultRowType} = Triceps::RowType->new(@resultdef);
	Carp::confess("$!") unless (ref $self->{resultRowType} eq "Triceps::RowType");

	# create the input label
	$self->{inputLabel} = $self->{unit}->makeLabel($self->{leftRowType}, $self->{name} . ".in", 
		undef, \&handleInput, $self);
	Carp::confess("$!") unless (ref $self->{inputLabel} eq "Triceps::Label");
	# create the output label
	$self->{outputLabel} = $self->{unit}->makeDummyLabel($self->{resultRowType}, $self->{name} . ".out");
	Carp::confess("$!") unless (ref $self->{outputLabel} eq "Triceps::Label");

	bless $self, $class;
	return $self;
}

# A version that creates a lookup join that always feeds through the input
# label and does not support the lookup() call. This allows
# to always take the opcode into the account, and is used by JoinTwo.
# Would it be better as an option in new(), or maybe as a separate class?
# So far a separate constructor looks like the easiest option that
# does not muddle the basic code, but on the other hand leads to code duplication.
#
# Options:
# unit - unit object
# name - name of this object (will be used to create the names of internal objects)
# leftRowType - type of the rows that will be used for lookup
# rightTable - table object where to do the look-ups
# rightIndex (optional) - name of index type in table used for look-up (default: first Hash),
#    index absolutely must be a Hash (leaf or not), not of any other kind
# leftFields (optional) - reference to array of patterns for left fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
# rightFields (optional) - reference to array of patterns for right fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
#    (which is probably a bad idea since it would include duplicate fields from the 
#    index, so override it)
# fieldsLeftFirst (optional) - flag: in the resulting records put the fields from
#    the left record first, then from right record, or if 0, then opposite. (default:1)
# by - reference to array, containing pairs of field names used for look-up,
#    [ leftFld1, rightFld1, leftFld2, rightFld2, ... ]
#    XXX production version should allow an arbitrary expression on the left?
# isLeft (optional) - 1 for left join, 0 for full join (default: 1)
# limitOne (optional) - 1 to return no more than one record, 0 otherwise (default: 0)
# oppositeOuter (optional) - flag: this is a half of a JoinTwo, and the other
#    half performs an outer (from its standpoint, left) join. For this side,
#    this means that a successfull lookup must generate a DELETE-INSERT pair.
#    (default: 0)
sub newAutomatic # (class, optionName => optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
			unit => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			leftRowType => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::RowType") } ],
			rightTable => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
			rightIndex => [ undef, sub { &Triceps::Opt::ck_ref(@_, "") } ], # a plain string, not a ref
			leftFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			rightFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			fieldsLeftFirst => [ 1, undef ],
			by => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			isLeft => [ 1, undef ],
			limitOne => [ 0, undef ],
			oppositeOuter => [ 0, undef ],
		}, @_);

	$self->{rightRowType} = $self->{rightTable}->getRowType();

	my @leftdef = $self->{leftRowType}->getdef();
	my %leftmap = $self->{leftRowType}->getFieldMapping();
	my @leftfld = $self->{leftRowType}->getFieldNames();

	my @rightdef = $self->{rightRowType}->getdef();
	my %rightmap = $self->{rightRowType}->getFieldMapping();
	my @rightfld = $self->{rightRowType}->getFieldNames();

	# XXX use getKey() to check that the "by" keys match the
	# keys of the index
	# XXX also in production should check the matching []-ness of fields

	# Generate the join function with arguments:
	# @param self - this object
	# @param row - row argument
	# @return - an array of joined rows
	my $genjoin = '
		sub # ($inLabel, $rowop, $self)
		{
			my ($inLabel, $rowop, $self) = @_;
			#print STDERR "DEBUGX LookupJoin " . $self->{name} . " in: ", $rowop->printP(), "\n";

			my $opcode = $rowop->getOpcode(); # pass the opcode
			my $row = $rowop->getRow();

			my @leftdata = $row->toArray();

			my $resRowType = $self->{resultRowType};
			my $resLabel = $self->{outputLabel};
		';

	# create the look-up row (and check that "by" contains the correct field names)
	$genjoin .= '
			my $lookuprow = $self->{rightRowType}->makeRowHash(
				';
	my @cpby = @{$self->{by}};
	while ($#cpby >= 0) {
		my $lf = shift @cpby;
		my $rt = shift @cpby;
		Carp::confess("Option 'by' contains an unknown left-side field '$lf'")
			unless defined $leftmap{$lf};
		Carp::confess("Option 'by' contains an unknown right-side field '$rt'")
			unless defined $rightmap{$rt};
		$genjoin .= $rt . ' => $leftdata[' . $leftmap{$lf} . "],\n\t\t\t\t";
	}
	$genjoin .= ");\n\t\t\t";

	# translate the index
	if (defined $self->{rightIndex}) {
		$self->{rightIdxType} = $self->{rightTable}->getType()->findSubIndex($self->{rightIndex});
		Carp::confess("The table does not have a top-level index '" . $self->{rightIndex} . "' for joining")
			unless defined $self->{rightIdxType};
		my $ixid  = $self->{rightIdxType}->getIndexId();
		Carp::confess("The index '" . $self->{rightIndex} . "' is of kind '" . &Triceps::indexIdString($ixid) . "', not IT_HASHED as required")
			unless ($ixid == &Triceps::IT_HASHED);
	} else {
		$self->{rightIdxType} = $self->{rightTable}->findSubIndexById(&Triceps::IT_HASHED);
		Carp::confess("The table does not have a top-level Hash index for joining")
			unless defined $self->{rightIdxType};
	}
	if (!$self->{limitOne}) { # would need a sub-index for iteration
		my @subs = $self->{rightIdxType}->getSubIndexes();
		if ($#subs < 0) { # no sub-indexes, so guaranteed to match one record
			#print STDERR "DEBUG auto-deducing limitOne=1 subs=(", join(", ", @subs), ")\n";
			$self->{limitOne} = 1;
		} else {
			$self->{iterIdxType} = $subs[1]; # first index type object, they go in (name => type) pairs
			# (all sub-indexes are equivalent for our purpose, just pick first)
		}
	}

	##########################################################################
	# build the code that will produce one result record by combining
	# @leftdata and @rightdata into @resdata;
	# also for oppositeOuter add a special case for the opposite opcode 
	# and empty right data in @oppdata

	my $genresdata .= '
				my @resdata = (';
	my $genoppdata .= '
				my @oppdata = (';

	my @resultdef;
	my %resultmap; 
	my @resultfld;
	
	# reference the variables for access by left/right iterator
	my %choice = (
		leftdef => \@leftdef,
		leftmap => \%leftmap,
		leftfld => \@leftfld,
		rightdef => \@rightdef,
		rightmap => \%rightmap,
		rightfld => \@rightfld,
	);
	my @order = ($self->{fieldsLeftFirst} ? ("left", "right") : ("right", "left"));
	#print STDERR "DEBUG order is ", $self->{fieldsLeftFirst}, ": (", join(", ", @order), ")\n";
	for my $side (@order) {
		my $orig = $choice{"${side}fld"};
		my @trans = &filterFields($orig, $self->{"${side}Fields"});
		my $smap = $choice{"${side}map"};
		for ($i = 0; $i <= $#trans; $i++) {
			my $f = $trans[$i];
			#print STDERR "DEBUG ${side} [$i] is '" . (defined $f? $f : '-undef-') . "'\n";
			next unless defined $f;
			if (exists $resultmap{$f}) {
				Carp::confess("A duplicate field '$f' is produced from  ${side}-side field '"
					. $orig->[$i] . "'; the preceding fields are: (" . join(", ", @resultfld) . ")" )
			}
			my $index = $smap->{$orig->[$i]};
			#print STDERR "DEBUG   index=$index smap=(" . join(", ", %$smap) . ")\n";
			push @resultdef, $f, $choice{"${side}def"}->[$index*2 + 1];
			push @resultfld, $f;
			$resultmap{$f} = $#resultfld; # fix the index
			$genresdata .= '$' . $side . 'data[' . $index . "],\n\t\t\t\t";
			if ($side eq "right") {
				$genoppdata .= '$' . $side . 'data[' . $index . "],\n\t\t\t\t";
			} else {
				$genoppdata .= "undef,\n\t\t\t\t"; # empty filler for left (our) side
			}
		}
	}
	$genresdata .= ');
				my $resrowop = $resLabel->makeRowop($opcode, $resRowType->makeRowArray(@resdata));
				#print STDERR "DEBUGX " . $self->{name} . " +out: ", $resrowop->printP(), "\n";
				Carp::confess("$!") unless defined $resrowop;
				Carp::confess("$!") 
					unless $resLabel->getUnit()->call($resrowop);
				';
	# XXX add genoppdata
	$genoppdata .= ');
				my $opprowop = $resLabel->makeRowop(
					&Triceps::isInsert($opcode)? &Triceps::OP_DELETE : &Triceps::OP_INSERT,
					, $resRowType->makeRowArray(@oppdata));
				#print STDERR "DEBUGX " . $self->{name} . " +out: ", $opprowop->printP(), "\n";
				Carp::confess("$!") unless defined $opprowop;
				Carp::confess("$!") 
					unless $resLabel->getUnit()->call($opprowop);
				';

	# end of result record
	##########################################################################

	# do the look-up
	$genjoin .= '
			#print STDERR "DEBUGX " . $self->{name} . " lookup: ", $lookuprow->printP(), "\n";
			my $rh = $self->{rightTable}->findIdx($self->{rightIdxType}, $lookuprow);
			Carp::confess("$!") unless defined $rh;
		';
	$genjoin .= '
			my @rightdata; # fields from the right side, defaults to all-undef, if no data found
			my @result; # the result rows will be collected here
		';
	if ($self->{limitOne}) { # an optimized version that returns no more than one row
		if (! $self->{isLeft}) {
			# a shortcut for full join if nothing is found
			$genjoin .= '
			return () if $rh->isNull();
			#print STDERR "DEBUGX " . $self->{name} . " found data: " . $rh->getRow()->printP() . "\n";
			@rightdata = $rh->getRow()->toArray();
';
		} else {
			$genjoin .= '
			if (!$rh->isNull()) {
				#print STDERR "DEBUGX " . $self->{name} . " found data: " . $rh->getRow()->printP() . "\n";
				@rightdata = $rh->getRow()->toArray();
			}
';
		}
		if ($self->{oppositeOuter}) {
			$genjoin .= '
			if (!$rh->isNull()) {
				if (&Triceps::isInsert($opcode)) {
' . $genoppdata . '
' . $genresdata . '
				} elsif (&Triceps::isDelete($opcode)) {
' . $genresdata . '
' . $genoppdata . '
				}
			} else {
' . $genresdata . '
			}
';
		} else {
			$genjoin .= $genresdata;
		}
	} else {
		$genjoin .= '
			if ($rh->isNull()) {
				#print STDERR "DEBUGX " . $self->{name} . " found NULL\n";
'; 
		if ($self->{isLeft}) {
			$genjoin .= $genresdata;
		} else {
			$genjoin .= '
				return ();';
		}

		$genjoin .= '
			} else {
				#print STDERR "DEBUGX " . $self->{name} . " found data: " . $rh->getRow()->printP() . "\n";
				my $endrh = $self->{rightTable}->nextGroupIdx($self->{iterIdxType}, $rh);
				for (; !$rh->same($endrh); $rh = $self->{rightTable}->nextIdx($self->{rightIdxType}, $rh)) {
					@rightdata = $rh->getRow()->toArray();';
		if ($self->{oppositeOuter}) {
			$genjoin .= '
					if (&Triceps::isInsert($opcode)) {
' . $genoppdata . '
' . $genresdata . '
					} elsif (&Triceps::isDelete($opcode)) {
' . $genresdata . '
' . $genoppdata . '
					}
';
		} else {
			$genjoin .= $genresdata;
		}
		$genjoin .= '
				}
			}';
	}

	$genjoin .= '
		}'; # end of function

	#print STDERR "DEBUG $genjoin\n";

	undef $@;
	eval "\$self->{joinerAutomatic} = $genjoin;"; # compile!
	Carp::confess("Internal error: LookupJoin failed to compile the joiner function:\n$@\n")
		if $@;

	# now create the result row type
	#print STDERR "DEBUG result type def = (", join(", ", @resultdef), ")\n"; # DEBUG
	$self->{resultRowType} = Triceps::RowType->new(@resultdef);
	Carp::confess("$!") unless (ref $self->{resultRowType} eq "Triceps::RowType");

	# create the input label
	$self->{inputLabel} = $self->{unit}->makeLabel($self->{leftRowType}, $self->{name} . ".in", 
		undef, $self->{joinerAutomatic}, $self);
	Carp::confess("$!") unless (ref $self->{inputLabel} eq "Triceps::Label");
	# create the output label
	$self->{outputLabel} = $self->{unit}->makeDummyLabel($self->{resultRowType}, $self->{name} . ".out");
	Carp::confess("$!") unless (ref $self->{outputLabel} eq "Triceps::Label");

	bless $self, $class;
	return $self;
}

# XXX Thoughts for the future result specification:
#  result_fld_name: (may be a substitution regexp translated from the source field)
#      optional type
#      list of source field specs (hardcoded, range, pattern, exclusion hardcoded, exclusion pattern),
#        including the source name;
#        maybe picking first non-null from multiple sources (such as for the key fields)

# Process the list of field names according to the filter spec.
# @param incoming - reference to the original array of field names
# @param patterns - reference to the array of filter patterns (undef means 
#   "no filtering, pass as is")
# @return - an array of filtered field names, positionally mathing the
#    names in the original array, with undefs for the thrown-away fields
#
# Does NOT check for name correctness, duplicates etc.
#
# Pattern rules:
# For each field, all the patterns are applied in order until one of
# them matches. If none matches, the field gets thrown away by default.
# The possible pattern formats are:
#    "regexp" - pass through the field names matching the anchored regexp
#        (i.e. implicitly wrapped as "^regexp$"). Must not
#        contain the literal "/" anywhere. And since the field names are
#        alphanumeric, specifying the field name will pass that field through.
#        To pass through the rest of fields, use the pattern ".*".
#    "!regexp" - throw away the field names matching the anchored regexp.
#    "regexp/regsub" - pass through the field names matching the anchored regexp,
#        performing a substitution on it. For example, '.*/second_$&/'
#        would pass through all the fields, prefixing them with "second_".
#
# XXX If this works well, it should probably be moved into Triceps::
sub filterFields() # (\@incoming, \@patterns) # no $self, it's a static method!
{
	my $incoming = shift;
	my $patterns = shift;

	if (!defined $patterns) {
		return @$incoming; # just pass through everything
	}

	my (@res, $f, $ff, $t, $p, $pp, $s);

	# since this is normally executed at the model compilation stage,
	# the performance here doesn't matter a whole lot, and the logic
	# can be done in the simple non-optimized loops
	foreach $f (@$incoming) {
		undef $t;
		foreach $p (@$patterns) {
			if ($p =~ /^!(.*)/) { # negative pattern
				$pp = $1;
				last if ($f =~ /^$pp$/);
			} elsif ($p =~ /^([^\/]*)\/([^\/]*)/ ) { # substitution
				$pp = $1;
				$s = $2;
				$ff = $f;
				if (eval("\$ff =~ s/^$pp\$/$s/;")) { # eval is needed for $s to evaluate right
					$t = $ff;
					last;
				}
			} else { # simple positive pattern
				if ($f =~ /^$p$/) {
					$t = $f;
					last;
				}
			}
		}
		push @res, $t;
	}
	return @res;
}

# Perofrm the look-up by left row in the right table and return the
# result rows(s).
# @param self
# @param leftRow - left-side row for performing the look-up
# @return - array of result rows (if not isLeft then may be empty)
sub lookup() # (self, leftRow)
{
	my ($self, $leftRow) = @_;
	my @result = &{$self->{joiner}}($self, $leftRow);
	#print STDERR "DEBUG lookup result=(", join(", ", @result), ")\n";
	return @result;
}

# Handle the input records 
# @param label - input label
# @param rowop - incoming row
# @param self - this object
sub handleInput # ($label, $rowop, $self)
{
	my ($label, $rowop, $self) = @_;

	my $opcode = $rowop->getOpcode(); # pass the opcode

	# if many rows get selected, this may result in a huge array,
	# but then again, in any case the rowops would need to be created for all of them
	my @resRows = &{$self->{joiner}}($self, $rowop->getRow());
	my $resultLab = $self->{outputLabel};
	my $resultRowop;
	foreach my $resultRow( @resRows ) {
		$resultRowop = $resultLab->makeRowop($opcode, $resultRow);
		Carp::confess("$!") unless defined $resultRowop;
		Carp::confess("$!") 
			unless $resultLab->getUnit()->call($resultRowop);
	}
}

sub getResultRowType() # (self)
{
	my $self = shift;
	return $self->{resultRowType};
}

sub getInputLabel() # (self)
{
	my $self = shift;
	return $self->{inputLabel};
}

sub getOutputLabel() # (self)
{
	my $self = shift;
	return $self->{outputLabel};
}

# XXX for production should add getters for other fields

1;
