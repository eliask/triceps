#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# An application example of joins between a data stream and a table.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 124 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################

############################# helper functions ###########################

# helper function to feed the input data to a label
sub feedInput # ($label, $opcode, @$dataArray)
{
	my ($label, $opcode, $dataArray) = @_;
	my $unit = $label->getUnit();
	my $rt = $label->getType();
	foreach my $tuple (@$dataArray) {
		# print STDERR "feed [" . join(", ", @$tuple) . "]\n";
		my $rowop = $label->makeRowop($opcode, $rt->makeRowArray(@$tuple));
		$unit->schedule($rowop);
	}
}

# convert a data set to a string
sub dataToString # (@dataSet)
{
	my $res;
	foreach my $tuple (@_) {
		$res .= "(" . join(", ", @$tuple) . ")\n";
	}
	return $res;
}

#######################################################################
# 1. A hardcoded manual left join using a primary key on the right.
# Performs the look-up of the internal "canonical" account ids from the
# external ones, coming from different system.

# incoming data:
@defInTrans = ( # a transaction received
	acctSrc => "string", # external system that sent us a transaction
	acctXtrId => "string", # its name of the account of the transaction
	amount => "int32", # the amount of transaction (int is easier to check)
);
$rtInTrans = Triceps::RowType->new(
	@defInTrans
);
ok(ref $rtInTrans, "Triceps::RowType");

@incomingData = (
	[ "source1", "999", 100 ], 
	[ "source2", "ABCD", 200 ], 
	[ "source3", "ZZZZ", 300 ], 
	[ "source1", "2011", 400 ], 
	[ "source2", "ZZZZ", 500 ], 
);

# result data:
@defOutTrans = ( # a transaction received
	@defInTrans, # just add a field to an existing definition
	acct => "int32", # our internal account id
);
$rtOutTrans = Triceps::RowType->new(
	@defOutTrans
);
ok(ref $rtOutTrans, "Triceps::RowType");

# look-up data
@defAccounts = ( # account translation map
	source => "string", # external system that sent us a transaction
	external => "string", # its name of the account of the transaction
	internal => "int32", # our internal account id
);
$rtAccounts = Triceps::RowType->new(
	@defAccounts
);
ok(ref $rtAccounts, "Triceps::RowType");
	
@accountData = (
	[ "source1", "999", 1 ],
	[ "source1", "2011", 2 ],
	[ "source1", "42", 3 ],
	[ "source2", "ABCD", 1 ],
	[ "source2", "QWERTY", 2 ],
	[ "source2", "UIOP", 4 ],
);

### here goes the code

$vu1 = Triceps::Unit->new("vu1");
ok(ref $vu1, "Triceps::Unit");

# this will record the results
my $result1;

# the accounts table
$ttAccounts = Triceps::TableType->new($rtAccounts)
	# muliple indexes can be defined for different purposes
	# (though of course each extra index adds overhead)
	->addSubIndex("lookupSrcExt", # quick look-up by source and external id
		Triceps::IndexType->newHashed(key => [ "source", "external" ])
	)
	->addSubIndex("iterateSrc", # for iteration in order grouped by source
		Triceps::IndexType->newHashed(key => [ "source" ])
		->addSubIndex("iterateSrcExt", 
			Triceps::IndexType->newHashed(key => [ "external" ])
		)
	)
	->addSubIndex("lookupIntGroup", # quick look-up by internal id (to multiple externals)
		Triceps::IndexType->newHashed(key => [ "internal" ])
		->addSubIndex("lookupInt", Triceps::IndexType->newFifo())
	)
; 
ok(ref $ttAccounts, "Triceps::TableType");
# remember the index for quick lookup
$idxAccountsLookup = $ttAccounts->findSubIndex("lookupSrcExt");
ok(ref $idxAccountsLookup, "Triceps::IndexType");

$res = $ttAccounts->initialize();
ok($res, 1);

$tAccounts = $vu1->makeTable($ttAccounts, &Triceps::EM_CALL, "Accounts");
ok(ref $tAccounts, "Triceps::Table");

# function to perform the join
# @param resultLab - label to send the result
# @param enqMode - enqueueing mode for the result
sub join1 # ($label, $rowop, $resultLab, $enqMode)
{
	my ($label, $rowop, $resultLab, $enqMode) = @_;

	$result1 .= $rowop->printP() . "\n";

	my %rowdata = $rowop->getRow()->toHash(); # result easier to handle manually than from toArray
	my $intacct; # if lookup fails, may be undef, since it's a left join
	# perform the look-up
	my $lookupRow = $rtAccounts->makeRowHash(
		source => $rowdata{acctSrc},
		external => $rowdata{acctXtrId},
	);
	Carp::confess("$!") unless defined $lookupRow;
	my $acctrh = $tAccounts->findIdx($idxAccountsLookup, $lookupRow);
	# if the translation is not found, in production it might be useful
	# to send the record to the error handling logic instead
	if (!$acctrh->isNull()) { 
		$intacct = $acctrh->getRow()->get("internal");
	}
	# create the result
	my $resultRow = $rtOutTrans->makeRowHash(
		%rowdata,
		acct => $intacct,
	);
	Carp::confess("$!") unless defined $resultRow;
	my $resultRowop = $resultLab->makeRowop($rowop->getOpcode(), # pass the opcode
		$resultRow);
	Carp::confess("$!") unless defined $resultRowop;
	Carp::confess("$!") 
		unless $resultLab->getUnit()->enqueue($enqMode, $resultRowop);
}

my $outlab1 = $vu1->makeLabel($rtOutTrans, "out", undef, sub { $result1 .= $_[1]->printP() . "\n" } );
ok(ref $outlab1, "Triceps::Label");

my $inlab1 = $vu1->makeLabel($rtInTrans, "in", undef, \&join1, $outlab1, &Triceps::EM_CALL);
ok(ref $inlab1, "Triceps::Label");

# fill the accounts table
&feedInput($tAccounts->getInputLabel(), &Triceps::OP_INSERT, \@accountData);
$vu1->drainFrame();
ok($vu1->empty());

# feed the data
&feedInput($inlab1, &Triceps::OP_INSERT, \@incomingData);
&feedInput($inlab1, &Triceps::OP_DELETE, \@incomingData);
$vu1->drainFrame();
ok($vu1->empty());

#print STDERR $result1;
$expect1 = 
'in OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" 
out OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
in OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" 
out OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
in OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
out OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" 
out OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
in OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
out OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
in OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" 
out OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
in OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" 
out OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
in OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
out OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" 
out OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
in OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
out OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
';
ok($result1, $expect1);

#######################################################################
# 2. A class for the straightforward stream-to-table lookup
# It had come out with a kind of wide functionality, so it would
# require multiple tests, marked by letters ("2a" etc.).

package LookupJoin;

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
					unless $resLabel->getUnit()->enqueue(&Triceps::EM_CALL, $resrowop);
				';
	# XXX add genoppdata
	$genoppdata .= ');
				my $opprowop = $resLabel->makeRowop(
					&Triceps::isInsert($opcode)? &Triceps::OP_DELETE : &Triceps::OP_INSERT,
					, $resRowType->makeRowArray(@oppdata));
				#print STDERR "DEBUGX " . $self->{name} . " +out: ", $opprowop->printP(), "\n";
				Carp::confess("$!") unless defined $opprowop;
				Carp::confess("$!") 
					unless $resLabel->getUnit()->enqueue(&Triceps::EM_CALL, $opprowop);
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

#####################################################
# A little test of filterFields by itself

@res = &filterFields([ 'abc', 'def' ], undef);
main::ok(join(",", map { defined $_? $_ : "-" } @res), "abc,def"); # all positive if no patterns

@res = &filterFields([ 'abc', 'def', 'ghi' ], [ 'abc', 'def' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "abc,def,-");

@res = &filterFields([ 'abc', 'def', 'ghi' ], [ '!abc' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "-,-,-"); # check for default being "throwaway" even with purely negative
@res = &filterFields([ 'abc', 'def', 'ghi' ], [ ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "-,-,-"); # empty pattern means throw away everything

@res = &filterFields([ 'abc', 'def', 'ghi' ], [ '!abc', '.*' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "-,def,ghi");

@res = &filterFields([ 'abc', 'adef', 'gahi' ], [ '!abc', 'a.*' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "-,adef,-"); # first match wins, and check front anchoring

@res = &filterFields([ 'abc', 'adef', 'gahi' ], [ '...' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "abc,-,-"); # anchoring

@res = &filterFields([ 'abc', 'def', 'ghi' ], [ '!a.*', '.*' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "-,def,ghi"); # negative pattern

@res = &filterFields([ 'abc', 'def', 'ghi' ], [ '.*/second_$&' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "second_abc,second_def,second_ghi"); # substitution

@res = &filterFields([ 'abc', 'defg', 'ghi' ], [ '(.).(.)/$1x$2' ] );
main::ok(join(",", map { defined $_? $_ : "-" } @res), "axc,-,gxi"); # anchoring and numbered sub-expressions

#####################################################

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

	my @resRows = &{$self->{joiner}}($self, $rowop->getRow());
	my $resultLab = $self->{outputLabel};
	my $resultRowop;
	foreach my $resultRow( @resRows ) {
		$resultRowop = $resultLab->makeRowop($opcode, $resultRow);
		Carp::confess("$!") unless defined $resultRowop;
		Carp::confess("$!") 
			unless $resultLab->getUnit()->enqueue(&Triceps::EM_CALL, $resultRowop);
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
# XXX also needs to be tested for errors

package main;

# the data definitions and examples are shared with example (1)

$vu2 = Triceps::Unit->new("vu2");
ok(ref $vu2, "Triceps::Unit");

# this will record the results
my $result2;

# the accounts table type is also reused from example (1)
$tAccounts2 = $vu2->makeTable($ttAccounts, &Triceps::EM_CALL, "Accounts");
ok(ref $tAccounts2, "Triceps::Table");

#########
# (2a) left join with an exactly-matching key that automatically triggers
# the limitOne flag to be true, using the direct lookup() call

$join2ab = LookupJoin->new( # will be used in both (2a) and (2b)
	unit => $vu2,
	name => "join2ab",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2,
	rightIndex => "lookupSrcExt",
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
);
ok(ref $join2ab, "LookupJoin");

sub calljoin2 # ($label, $rowop, $join, $resultLab)
{
	my ($label, $rowop, $join, $resultLab) = @_;

	$result2 .= $rowop->printP() . "\n";

	my $opcode = $rowop->getOpcode(); # pass the opcode

	my @resRows = $join->lookup($rowop->getRow());
	foreach my $resultRow( @resRows ) {
		my $resultRowop = $resultLab->makeRowop($opcode, $resultRow);
		Carp::confess("$!") unless defined $resultRowop;
		Carp::confess("$!") 
			unless $resultLab->getUnit()->call($resultRowop);
	}
}

my $outlab2a = $vu2->makeLabel($join2ab->getResultRowType(), "out", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $outlab2a, "Triceps::Label");

my $inlab2a = $vu2->makeLabel($rtInTrans, "in", undef, \&calljoin2, $join2ab, $outlab2a);
ok(ref $inlab2a, "Triceps::Label");

# fill the accounts table
&feedInput($tAccounts2->getInputLabel(), &Triceps::OP_INSERT, \@accountData);
$vu2->drainFrame();
ok($vu2->empty());

# feed the data
&feedInput($inlab2a, &Triceps::OP_INSERT, \@incomingData);
&feedInput($inlab2a, &Triceps::OP_DELETE, \@incomingData);
$vu2->drainFrame();
ok($vu2->empty());

#print STDERR $result2;
# expect same result as in test 1
ok($result2, $expect1);

#########
# (2b) Exact same as 2a, even reuse the same join, but work through its labels

my $outlab2b = $vu2->makeLabel($join2ab->getResultRowType(), "out", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $outlab2b, "Triceps::Label");

ok(ref $join2ab->getInputLabel(), "Triceps::Label");
ok(ref $join2ab->getOutputLabel(), "Triceps::Label");

# the output
ok($join2ab->getOutputLabel()->chain($outlab2b));

# this is purely to keep track of the input in the log
my $inlab2b = $vu2->makeLabel($rtInTrans, "in", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $inlab2b, "Triceps::Label");
ok($inlab2b->chain($join2ab->getInputLabel()));

undef $result2;
# feed the data
&feedInput($inlab2b, &Triceps::OP_INSERT, \@incomingData);
&feedInput($inlab2b, &Triceps::OP_DELETE, \@incomingData);
$vu2->drainFrame();
ok($vu2->empty());

#print STDERR $result2;
# expect same result as in test 1, except for different label names
# (since when a rowop is printed, it prints the name of the label for which it was created)
$expect2b = $expect1;
$expect2b =~ s/out OP/join2ab.out OP/g;
ok($result2, $expect2b);


#########
# (2c) inner join with an exactly-matching key that automatically triggers
# the limitOne flag to be true, using the labels

# reuses the same table, whih is already populated

$join2c = LookupJoin->new(
	unit => $vu2,
	name => "join2c",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2,
	rightIndex => "lookupSrcExt",
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 0,
);
ok(ref $join2c, "LookupJoin");

my $outlab2c = $vu2->makeLabel($join2c->getResultRowType(), "out", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $outlab2c, "Triceps::Label");

ok(ref $join2c->getInputLabel(), "Triceps::Label");
ok(ref $join2c->getOutputLabel(), "Triceps::Label");

# the output
ok($join2c->getOutputLabel()->chain($outlab2c));

# this is purely to keep track of the input in the log
my $inlab2c = $vu2->makeLabel($rtInTrans, "in", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $inlab2c, "Triceps::Label");
ok($inlab2c->chain($join2c->getInputLabel()));

undef $result2;
# feed the data
&feedInput($inlab2c, &Triceps::OP_INSERT, \@incomingData);
&feedInput($inlab2c, &Triceps::OP_DELETE, \@incomingData);
$vu2->drainFrame();
ok($vu2->empty());

#print STDERR $result2;
# now the rows with empty right side must be missing
$expect2c = 
'in OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" 
join2c.out OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
in OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2c.out OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
in OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" 
join2c.out OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
in OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
in OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" 
join2c.out OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
in OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2c.out OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
in OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" 
join2c.out OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
in OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
';
ok($result2, $expect2c);

#########
# (2d) inner join with limitOne = 0

# the accounts table will have 2 copies of each record, for tests (d) and (e)
$ttAccounts2de = Triceps::TableType->new($rtAccounts)
	# muliple indexes can be defined for different purposes
	# (though of course each extra index adds overhead)
	->addSubIndex("lookupSrcExt", # quick look-up by source and external id
		Triceps::IndexType->newHashed(key => [ "source", "external" ])
		->addSubIndex("fifo", Triceps::IndexType->newFifo())
	)
; 
ok(ref $ttAccounts2de, "Triceps::TableType");

$res = $ttAccounts2de->initialize();
ok($res, 1);

$tAccounts2de = $vu2->makeTable($ttAccounts2de, &Triceps::EM_CALL, "Accounts2de");
ok(ref $tAccounts2de, "Triceps::Table");

# fill the accounts table
&feedInput($tAccounts2de->getInputLabel(), &Triceps::OP_INSERT, \@accountData);
@accountData2de = ( # the second records, with different internal accounts
	[ "source1", "999", 11 ],
	[ "source1", "2011", 12 ],
	[ "source1", "42", 13 ],
	[ "source2", "ABCD", 11 ],
	[ "source2", "QWERTY", 12 ],
	[ "source2", "UIOP", 14 ],
);
&feedInput($tAccounts2de->getInputLabel(), &Triceps::OP_INSERT, \@accountData2de);
$vu2->drainFrame();
ok($vu2->empty());

# inner join with no limit to 1 record
$join2d = LookupJoin->new(
	unit => $vu2,
	name => "join2d",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2de,
	rightIndex => "lookupSrcExt",
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 0,
);
ok(ref $join2d, "LookupJoin");

my $outlab2d = $vu2->makeLabel($join2d->getResultRowType(), "out", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $outlab2d, "Triceps::Label");

# the output
ok($join2d->getOutputLabel()->chain($outlab2d));

# this is purely to keep track of the input in the log
my $inlab2d = $vu2->makeLabel($rtInTrans, "in", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $inlab2d, "Triceps::Label");
ok($inlab2d->chain($join2d->getInputLabel()));

undef $result2;
# feed the data
&feedInput($inlab2d, &Triceps::OP_INSERT, \@incomingData);
&feedInput($inlab2d, &Triceps::OP_DELETE, \@incomingData);
$vu2->drainFrame();
ok($vu2->empty());

#print STDERR $result2;
# now the rows with empty right side must be missing
$expect2d = 
'in OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" 
join2d.out OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
join2d.out OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" acct="11" 
in OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2d.out OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
join2d.out OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" acct="11" 
in OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" 
join2d.out OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
join2d.out OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" acct="12" 
in OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
in OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" 
join2d.out OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
join2d.out OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" acct="11" 
in OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2d.out OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
join2d.out OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" acct="11" 
in OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" 
join2d.out OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
join2d.out OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" acct="12" 
in OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
';
ok($result2, $expect2d);

#########
# (2e) left join with limitOne = 0

# left join with no limit to 1 record
$join2e = LookupJoin->new(
	unit => $vu2,
	name => "join2e",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2de,
	rightIndex => "lookupSrcExt",
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
);
ok(ref $join2e, "LookupJoin");

my $outlab2e = $vu2->makeLabel($join2e->getResultRowType(), "out", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $outlab2e, "Triceps::Label");

# the output
ok($join2e->getOutputLabel()->chain($outlab2e));

# this is purely to keep track of the input in the log
my $inlab2e = $vu2->makeLabel($rtInTrans, "in", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $inlab2e, "Triceps::Label");
ok($inlab2e->chain($join2e->getInputLabel()));

undef $result2;
# feed the data
&feedInput($inlab2e, &Triceps::OP_INSERT, \@incomingData);
&feedInput($inlab2e, &Triceps::OP_DELETE, \@incomingData);
$vu2->drainFrame();
ok($vu2->empty());

#print STDERR $result2;
$expect2e = 
'in OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" 
join2e.out OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
join2e.out OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" acct="11" 
in OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2e.out OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
join2e.out OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" acct="11" 
in OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join2e.out OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" 
join2e.out OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
join2e.out OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" acct="12" 
in OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
join2e.out OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
in OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" 
join2e.out OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
join2e.out OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" acct="11" 
in OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2e.out OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
join2e.out OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" acct="11" 
in OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join2e.out OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" 
join2e.out OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
join2e.out OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" acct="12" 
in OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
join2e.out OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
';
ok($result2, $expect2e);

#########
# (2f) left join with limitOne = 1, and multiple records available

$join2f = LookupJoin->new(
	unit => $vu2,
	name => "join2f",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2de,
	rightIndex => "lookupSrcExt",
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
	limitOne => 1,
);
ok(ref $join2f, "LookupJoin");

my $outlab2f = $vu2->makeLabel($join2f->getResultRowType(), "out", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $outlab2f, "Triceps::Label");

# the output
ok($join2f->getOutputLabel()->chain($outlab2f));

# this is purely to keep track of the input in the log
my $inlab2f = $vu2->makeLabel($rtInTrans, "in", undef, sub { $result2 .= $_[1]->printP() . "\n" } );
ok(ref $inlab2f, "Triceps::Label");
ok($inlab2f->chain($join2f->getInputLabel()));

undef $result2;
# feed the data
&feedInput($inlab2f, &Triceps::OP_INSERT, \@incomingData);
&feedInput($inlab2f, &Triceps::OP_DELETE, \@incomingData);
$vu2->drainFrame();
ok($vu2->empty());

#print STDERR $result2;
$expect2f = 
'in OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" 
join2f.out OP_INSERT acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
in OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2f.out OP_INSERT acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
in OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join2f.out OP_INSERT acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" 
join2f.out OP_INSERT acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
in OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
join2f.out OP_INSERT acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
in OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" 
join2f.out OP_DELETE acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
in OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" 
join2f.out OP_DELETE acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
in OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join2f.out OP_DELETE acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
in OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" 
join2f.out OP_DELETE acctSrc="source1" acctXtrId="2011" amount="400" acct="2" 
in OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
join2f.out OP_DELETE acctSrc="source2" acctXtrId="ZZZZ" amount="500" 
';
ok($result2, $expect2f);

#######################################################################
# 3. A table-to-table join.
# It's the next step of complexity that still has serious limitations:
# joining only two tables, and no self-joins.
# It's implemented in a simple way by tying together 2 LookupJoins.

package JoinTwo;

# Options:
# unit - unit object
# name - name of this object (will be used to create the names of internal objects)
# leftTable - table object to join
# rightTable - table object to join
# leftIndex - name of index type in left table used for look-up,
#    index absolutely must be a Hash (leaf or not), not of any other kind
# rightIndex - name of index type in right table used for look-up,
#    index absolutely must be a Hash (leaf or not), not of any other kind;
#    the number and order of fields in left and right indexes must match
#    since indexes define the fields used for the join; the types of fields
#    don't have to match exactly since Perl will connvert them if possible
# leftFields (optional) - reference to array of patterns for left fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
# rightFields (optional) - reference to array of patterns for right fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
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
			leftIndex => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "") } ], # a plain string, not a ref
			rightIndex => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "") } ], # a plain string, not a ref
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
		$self->{"${side}IdxType"} = $self->{"${side}Table"}->getType()->findSubIndex($self->{"${side}Index"});
		Carp::confess("The $side table does not have a top-level index '" . $self->{"${side}Index"} . "' for joining")
			unless defined $self->{"${side}IdxType"};
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
	@leftkeys = $self->{leftIdxType}->getKey();
	@rightkeys = $self->{rightIdxType}->getKey();
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
	$self->{leftLookup} = LookupJoin->newAutomatic(
		unit => $self->{unit},
		name => $self->{name} . ".leftLookup",
		leftRowType => $self->{leftRowType},
		rightTable => $self->{rightTable},
		rightIndex => $self->{rightIndex},
		leftFields => $self->{leftFields},
		rightFields => $self->{rightFields},
		fieldsLeftFirst => 1,
		by => \@leftby,
		isLeft => $leftLeft,
		oppositeOuter => ($rightLeft && !$self->{simpleMinded}),
	);
	$self->{rightLookup} = LookupJoin->newAutomatic(
		unit => $self->{unit},
		name => $self->{name} . ".rightLookup",
		leftRowType => $self->{rightRowType},
		rightTable => $self->{leftTable},
		rightIndex => $self->{leftIndex},
		leftFields => $self->{rightFields},
		rightFields => $self->{leftFields},
		fieldsLeftFirst => 0,
		by => \@rightby,
		isLeft => $rightLeft,
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

sub getResultRowType() # (self)
{
	my $self = shift;
	return $self->{leftLookup}->getResultRowType();
}

sub getOutputLabel() # (self)
{
	my $self = shift;
	return $self->{outputLabel};
}

# XXX for production add more getter methods
# XXX test JoinTwo for errors

package main;

# This will work by producing multiple join results in parallel.
# There are 2 pairs of tables (an account table and 2 separate transaction tables),
# with assorted joins defined on them. As the data is fed to the tables, all
# joins generate and record the results.

$vu3 = Triceps::Unit->new("vu3");
ok(ref $vu3, "Triceps::Unit");

# this will record the results
my ($result3a, $result3b, $result3c, $result3d, $result3e, $result3f, $result3g);

# the accounts table type is also reused from example (1)
$tAccounts3 = $vu3->makeTable($ttAccounts, &Triceps::EM_CALL, "Accounts");
ok(ref $tAccounts3, "Triceps::Table");
$inacct3 = $tAccounts3->getInputLabel();
ok(ref $inacct3, "Triceps::Label");

# the incoming transactions table here adds an extra id field
@defTrans3 = ( # a transaction received
	id => "int32", # transaction id
	acctSrc => "string", # external system that sent us a transaction
	acctXtrId => "string", # its name of the account of the transaction
	amount => "int32", # the amount of transaction (int is easier to check)
);
$rtTrans3 = Triceps::RowType->new(
	@defTrans3
);
ok(ref $rtTrans3, "Triceps::RowType");

# the "honest" transaction table
$ttTrans3 = Triceps::TableType->new($rtTrans3)
	# muliple indexes can be defined for different purposes
	# (though of course each extra index adds overhead)
	->addSubIndex("primary", 
		Triceps::IndexType->newHashed(key => [ "id" ])
	)
	->addSubIndex("byAccount", # for joining by account info
		Triceps::IndexType->newHashed(key => [ "acctSrc", "acctXtrId" ])
		->addSubIndex("data", Triceps::IndexType->newFifo())
	)
; 
ok(ref $ttTrans3, "Triceps::TableType");
ok($ttTrans3->initialize());
$tTrans3 = $vu3->makeTable($ttTrans3, &Triceps::EM_CALL, "Trans");
ok(ref $tTrans3, "Triceps::Table");
$intrans3 = $tTrans3->getInputLabel();
ok(ref $intrans3, "Triceps::Label");

# the transaction table that has the join index as the primary key,
# as a hypothetical case that allows to test the logic dependent on it
$ttTrans3p = Triceps::TableType->new($rtTrans3)
	->addSubIndex("byAccount", # for joining by account info
		Triceps::IndexType->newHashed(key => [ "acctSrc", "acctXtrId" ])
	)
; 
ok(ref $ttTrans3p, "Triceps::TableType");
ok($ttTrans3p->initialize());
$tTrans3p = $vu3->makeTable($ttTrans3p, &Triceps::EM_CALL, "Trans");
ok(ref $tTrans3p, "Triceps::Table");
$intrans3p = $tTrans3p->getInputLabel();
ok(ref $intrans3p, "Triceps::Label");

# a common label for feeding input data for both transaction tables
$labtrans3 = $vu3->makeDummyLabel($rtTrans3, "input3");
ok(ref $labtrans3, "Triceps::Label");
ok($labtrans3->chain($intrans3));
ok($labtrans3->chain($intrans3p));

# for debugging, collect the table results
my $res_acct;
my $labAccounts3 = $vu3->makeLabel($tAccounts3->getRowType(), "labAccounts3", undef, sub { $res_acct .= $_[1]->printP() . "\n" } );
ok(ref $labAccounts3, "Triceps::Label");
ok($tAccounts3->getOutputLabel()->chain($labAccounts3));

my $res_trans;
my $labTrans3 = $vu3->makeLabel($tTrans3->getRowType(), "labTrans3", undef, sub { $res_trans .= $_[1]->printP() . "\n" } );
ok(ref $labTrans3, "Triceps::Label");
ok($tTrans3->getOutputLabel()->chain($labTrans3));

my $res_transp;
my $labTrans3p = $vu3->makeLabel($tTrans3p->getRowType(), "labTrans3p", undef, sub { $res_transp .= $_[1]->printP() . "\n" } );
ok(ref $labTrans3p, "Triceps::Label");
ok($tTrans3p->getOutputLabel()->chain($labTrans3p));

# create the joins
# inner
my $join3a = JoinTwo->new(
	unit => $vu3,
	name => "join3a",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIndex => "byAccount",
	rightIndex => "lookupSrcExt",
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	type => "inner",
);
ok(ref $join3a, "JoinTwo");

my $outlab3a = $vu3->makeLabel($join3a->getResultRowType(), "out3a", undef, sub { $result3a .= $_[1]->printP() . "\n" } );
ok(ref $outlab3a, "Triceps::Label");
ok($join3a->getOutputLabel()->chain($outlab3a));

# outer - with leaf index on left
my $join3b = JoinTwo->new(
	unit => $vu3,
	name => "join3b",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIndex => "byAccount",
	rightIndex => "lookupSrcExt",
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	type => "outer",
);
ok(ref $join3b, "JoinTwo");

my $outlab3b = $vu3->makeLabel($join3b->getResultRowType(), "out3b", undef, sub { $result3b .= $_[1]->printP() . "\n" } );
ok(ref $outlab3b, "Triceps::Label");
ok($join3b->getOutputLabel()->chain($outlab3b));

# left
my $join3c = JoinTwo->new(
	unit => $vu3,
	name => "join3c",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIndex => "byAccount",
	rightIndex => "lookupSrcExt",
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	type => "left",
);
ok(ref $join3c, "JoinTwo");

my $outlab3c = $vu3->makeLabel($join3c->getResultRowType(), "out3c", undef, sub { $result3c .= $_[1]->printP() . "\n" } );
ok(ref $outlab3c, "Triceps::Label");
ok($join3c->getOutputLabel()->chain($outlab3c));

# right - with leaf index on left
my $join3d = JoinTwo->new(
	unit => $vu3,
	name => "join3d",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIndex => "byAccount",
	rightIndex => "lookupSrcExt",
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	type => "right",
);
ok(ref $join3d, "JoinTwo");

my $outlab3d = $vu3->makeLabel($join3d->getResultRowType(), "out3d", undef, sub { $result3d .= $_[1]->printP() . "\n" } );
ok(ref $outlab3d, "Triceps::Label");
ok($join3d->getOutputLabel()->chain($outlab3d));

# inner - simpleMinded
my $join3e = JoinTwo->new(
	unit => $vu3,
	name => "join3e",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIndex => "byAccount",
	rightIndex => "lookupSrcExt",
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	type => "inner",
	simpleMinded => 1,
);
ok(ref $join3e, "JoinTwo");

my $outlab3e = $vu3->makeLabel($join3e->getResultRowType(), "out3e", undef, sub { $result3e .= $_[1]->printP() . "\n" } );
ok(ref $outlab3e, "Triceps::Label");
ok($join3e->getOutputLabel()->chain($outlab3e));

# left - simpleMinded
my $join3f = JoinTwo->new(
	unit => $vu3,
	name => "join3f",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIndex => "byAccount",
	rightIndex => "lookupSrcExt",
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	type => "left",
	simpleMinded => 1,
);
ok(ref $join3f, "JoinTwo");

my $outlab3f = $vu3->makeLabel($join3f->getResultRowType(), "out3f", undef, sub { $result3f .= $_[1]->printP() . "\n" } );
ok(ref $outlab3f, "Triceps::Label");
ok($join3f->getOutputLabel()->chain($outlab3f));

# right - simpleMinded
my $join3g = JoinTwo->new(
	unit => $vu3,
	name => "join3g",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIndex => "byAccount",
	rightIndex => "lookupSrcExt",
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	type => "right",
	simpleMinded => 1,
);
ok(ref $join3g, "JoinTwo");

my $outlab3g = $vu3->makeLabel($join3g->getResultRowType(), "out3g", undef, sub { $result3g .= $_[1]->printP() . "\n" } );
ok(ref $outlab3g, "Triceps::Label");
ok($join3g->getOutputLabel()->chain($outlab3g));

# now send the data
# helper function to feed the input data to a mix of labels
# @param dataArray - ref to an array of row descriptions, each of which is a ref to array of:
#    label, opcode, ref to array of fields
sub feedMixedInput # (@$dataArray)
{
	my $dataArray = shift;
	foreach my $entry (@$dataArray) {
		my ($label, $opcode, $tuple) = @$entry;
		my $unit = $label->getUnit();
		my $rt = $label->getType();
		my $rowop = $label->makeRowop($opcode, $rt->makeRowArray(@$tuple));
		$unit->schedule($rowop);
	}
}

@data3 = (
	[ $labtrans3, &Triceps::OP_INSERT, [ 1, "source1", "999", 100 ] ], 
	[ $inacct3, &Triceps::OP_INSERT, [ "source1", "999", 1 ] ],
	[ $inacct3, &Triceps::OP_INSERT, [ "source1", "2011", 2 ] ],
	[ $inacct3, &Triceps::OP_INSERT, [ "source1", "42", 3 ] ],
	[ $inacct3, &Triceps::OP_INSERT, [ "source2", "ABCD", 1 ] ],
	[ $labtrans3, &Triceps::OP_INSERT, [ 2, "source2", "ABCD", 200 ] ], 
	[ $labtrans3, &Triceps::OP_INSERT, [ 3, "source3", "ZZZZ", 300 ] ], 
	[ $labtrans3, &Triceps::OP_INSERT, [ 4, "source1", "999", 400 ] ], 
	[ $inacct3, &Triceps::OP_DELETE, [ "source1", "999", 1 ] ],
	[ $inacct3, &Triceps::OP_INSERT, [ "source1", "999", 4 ] ],
	[ $labtrans3, &Triceps::OP_INSERT, [ 4, "source1", "2011", 500 ] ], # will displace the original record in tTrans3
);

&feedMixedInput(\@data3);
$vu3->drainFrame();
ok($vu3->empty());

# XXX these results depend on the ordering of records in the hash index, so will fail on MSB-first machines
ok ($result3a, 
'join3a.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3a.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3a.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3a.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3a.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3a.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="4" 
join3a.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3a.leftLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3a.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_source="source1" ac_external="2011" ac_internal="2" 
');
ok ($result3b, 
'join3b.leftLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3b.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3b.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3b.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" 
join3b.rightLookup.out OP_INSERT ac_source="source1" ac_external="42" ac_internal="3" 
join3b.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3b.leftLookup.out OP_DELETE ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3b.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3b.leftLookup.out OP_INSERT id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3b.leftLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3b.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" 
join3b.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" 
join3b.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3b.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3b.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3b.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3b.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3b.leftLookup.out OP_DELETE ac_source="source1" ac_external="2011" ac_internal="2" 
join3b.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_source="source1" ac_external="2011" ac_internal="2" 
');
ok ($result3c, 
'join3c.leftLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3c.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3c.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3c.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3c.leftLookup.out OP_INSERT id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3c.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3c.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3c.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3c.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3c.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3c.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3c.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="4" 
join3c.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3c.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3c.leftLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3c.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_source="source1" ac_external="2011" ac_internal="2" 
');
ok ($result3d, 
'join3d.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3d.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" 
join3d.rightLookup.out OP_INSERT ac_source="source1" ac_external="42" ac_internal="3" 
join3d.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3d.leftLookup.out OP_DELETE ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3d.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3d.leftLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3d.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" 
join3d.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" 
join3d.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3d.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3d.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3d.leftLookup.out OP_DELETE ac_source="source1" ac_external="2011" ac_internal="2" 
join3d.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_source="source1" ac_external="2011" ac_internal="2" 
');
ok ($result3e, 
'join3e.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3e.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3e.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3e.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3e.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3e.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="4" 
join3e.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3e.leftLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3e.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_source="source1" ac_external="2011" ac_internal="2" 
');
ok ($result3f, 
'join3f.leftLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3f.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3f.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3f.leftLookup.out OP_INSERT id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3f.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3f.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3f.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3f.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="4" 
join3f.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3f.leftLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3f.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_source="source1" ac_external="2011" ac_internal="2" 
');
ok ($result3g, 
'join3g.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3g.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" 
join3g.rightLookup.out OP_INSERT ac_source="source1" ac_external="42" ac_internal="3" 
join3g.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3g.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3g.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3g.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="1" 
join3g.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="1" 
join3g.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_source="source1" ac_external="999" ac_internal="4" 
join3g.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3g.leftLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_source="source1" ac_external="999" ac_internal="4" 
join3g.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_source="source1" ac_external="2011" ac_internal="2" 
');

# for debugging
#print STDERR $result3f;
#print STDERR "---- acct ----\n";
#print STDERR $res_acct;
#print STDERR "---- trans ----\n";
#print STDERR $res_trans;
#print STDERR "---- transp ----\n";
#print STDERR $res_transp;
#print STDERR "---- acct dump ----\n";
#for (my $rh = $tAccounts3->beginIdx($idxAccountsLookup); !$rh->isNull(); $rh = $tAccounts3->nextIdx($idxAccountsLookup, $rh)) {
#	print STDERR $rh->getRow()->printP(), "\n";
#}
