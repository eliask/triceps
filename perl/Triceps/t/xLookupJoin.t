#
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
BEGIN { plan tests => 74 };
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

# Options (mostly mandatory):
# unit - unit object
# name - name of this object (will be used to create the names of internal objects)
# leftRowType - type of the rows that will be used for lookup
# leftDrop (optional) - reference to array of left-side field names to drop from the
#    results (default: empty)
# rightTable - table object where to do the look-ups
# rightIndex (optional) - name of index type in table used for look-up (default: first Hash),
#    index absolutely must be a Hash (leaf or not), not of any other kind
# rightCopy - reference to array of right-side field names to include in the
#    results
# rightRename (optional) - reference to array of new names for fields in rightCopy,
#    undef means "keep the name" (default: keep all names)
# leftFields (optional) - reference to array of patterns for left fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
# rightFields (optional) - reference to array of patterns for right fields to pass through,
#    syntax as described in filterFields(), if not defined then pass everything
#    (which is probably a bad idea since it would include duplicate fields from the 
#    index, so override it)
# by - reference to array, containing pairs of field names used for look-up,
#    [ leftFld1, rightFld1, leftFld2, rightFld2, ... ]
#    XXX production version should allow an arbitrary expression on the left?
# isLeft (optional) - 1 for left join, 0 for full join (default: 1)
# limitOne (optional) - 1 to return no more than one record, 0 otherwise (default: 0)
# enqMode - enqueuing mode for the output records, sent to the output label
sub new # (class, optionName => optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
			unit => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			leftRowType => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::RowType") } ],
			leftDrop => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			rightTable => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
			rightIndex => [ undef, sub { &Triceps::Opt::ck_ref(@_, "") } ], # a plain string, not a ref
			rightCopy => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			rightRename => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			leftFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			rightFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			by => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			isLeft => [ 1, undef ],
			limitOne => [ 0, undef ],
			enqMode => [ undef, \&Triceps::Opt::ck_mandatory ],
		}, @_);

	if (defined $self->{rightRename}
	&& $#{$self->{rightRename}} != $#{$self->{rightCopy}}) {
		Carp::confess("If option rightRename is used, it must be a ref to array of the same size as rightCopy");
	}

	$self->{rightRowType} = $self->{rightTable}->getRowType();

	my @leftdef = $self->{leftRowType}->getdef();
	my %leftmap = $self->{leftRowType}->getFieldMapping();
	my @leftfld = $self->{leftRowType}->getFieldNames();
	my %rightmap = $self->{rightRowType}->getFieldMapping();
	my @rightdef = $self->{rightRowType}->getdef();

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

			#print STDERR "DEBUGX LookupJoin in: ", $row->printP(), "\n";

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
	# build the code that will produce one result record from @resdata

	my $genresdata .= '
				my @resdata = (';
	# result will start with a copy of left side, possibly with fields dropped
	my @resultdef;
	my %resultmap = %leftmap; 
	my @resultfld;
	if (defined $self->{leftDrop}) {
		foreach my $f (@{$self->{leftDrop}}) { # indexes in %resultmap won't be correct in this loop, but fixed later
			Carp::confess("Option 'leftDrop' contains an unknown left-side field '$f'")
				unless defined $leftmap{$f};
			delete $resultmap{$f};
		}
		foreach my $f (@leftfld) {
			next unless defined $resultmap{$f};
			push @resultdef, $f, $leftdef[$leftmap{$f}*2 + 1];
			push @resultfld, $f;
			$resultmap{$f} = $#resultfld; # fix the index
			$genresdata .= '$leftdata[' . $leftmap{$f} . "],\n\t\t\t\t";
		}
	} else {
		@resultdef = @leftdef;
		@resultfld = @leftfld;
		$genresdata .= '@leftdata, ';
	}

	# now add the fields from right side
	my @rightRename;
	if (defined $self->{rightRename}) {
		@rightRename = @{$self->{rightRename}};
	}
	for (my $i = 0; $i <= $#{$self->{rightCopy}}; $i++) {
		#print STDERR "DEBUG resultmap=(", join (", ", %resultmap), ")\n";
		my $f = $self->{rightCopy}[$i];
		my $resf = $rightRename[$i];
		if (!defined $resf || $resf eq "") {
			$resf = $f;
		}
		Carp::confess("Option 'rightCopy' contains an unknown right-side field '$f'")
			unless defined $rightmap{$f};
		Carp::confess("Option 'rightCopy'/'rightRename' contains a duplicate result field '$resf'")
			if defined $resultmap{$resf};

		push @resultdef, $resf, $rightdef[$rightmap{$f}*2 + 1];
		push @resultfld, $resf;
		$resultmap{$resf} = $#resultfld;
		$genresdata .= '$rightdata[' . $rightmap{$f} . "],\n\t\t\t\t";
	}
	$genresdata .= ");";
	$genresdata .= '
				push @result, $self->{resultRowType}->makeRowArray(@resdata);';

	# end of result record
	##########################################################################

	# do the look-up
	$genjoin .= '
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
			@rightdata = $rh->getRow()->toArray();
';
		} else {
			$genjoin .= '
			if (!$rh->isNull()) {
				@rightdata = $rh->getRow()->toArray();
			}
';
		}
		$genjoin .= $genresdata;
	} else {
		$genjoin .= '
			if ($rh->isNull()) {
				#print STDERR "DEBUGX found NULL\n";
'; 
		if ($self->{isLeft}) {
			$genjoin .= $genresdata;
		} else {
			$genjoin .= '
				return ();';
		}

		$genjoin .= '
			} else {
				#print STDERR "DEBUGX found data\n";
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
	my $enqMode = $self->{enqMode};
	my $resultRowop;
	foreach my $resultRow( @resRows ) {
		$resultRowop = $resultLab->makeRowop($opcode, $resultRow);
		Carp::confess("$!") unless defined $resultRowop;
		Carp::confess("$!") 
			unless $resultLab->getUnit()->enqueue($enqMode, $resultRowop);
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
	rightCopy => [ "internal" ],
	rightRename => [ "acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
	enqMode => &Triceps::EM_CALL,
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
	rightCopy => [ "internal" ],
	rightRename => [ "acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	enqMode => &Triceps::EM_CALL,
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
	rightCopy => [ "internal" ],
	rightRename => [ "acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	enqMode => &Triceps::EM_CALL,
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
	rightCopy => [ "internal" ],
	rightRename => [ "acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
	enqMode => &Triceps::EM_CALL,
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
	rightCopy => [ "internal" ],
	rightRename => [ "acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
	limitOne => 1,
	enqMode => &Triceps::EM_CALL,
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
