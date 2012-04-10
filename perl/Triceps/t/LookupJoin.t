#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# An use example of joins between a data stream and a table.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 68 };
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
# The class is Triceps::LookupJoin.

# XXX also needs to be tested for errors

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

$join2ab = Triceps::LookupJoin->new( # will be used in both (2a) and (2b)
	unit => $vu2,
	name => "join2ab",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2,
	rightIdxPath => ["lookupSrcExt"],
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
);
ok(ref $join2ab, "Triceps::LookupJoin");

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

$join2c = Triceps::LookupJoin->new(
	unit => $vu2,
	name => "join2c",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2,
	rightIdxPath => ["lookupSrcExt"],
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 0,
);
ok(ref $join2c, "Triceps::LookupJoin");

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
$join2d = Triceps::LookupJoin->new(
	unit => $vu2,
	name => "join2d",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2de,
	rightIdxPath => ["lookupSrcExt"],
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 0,
);
ok(ref $join2d, "Triceps::LookupJoin");

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
$join2e = Triceps::LookupJoin->new(
	unit => $vu2,
	name => "join2e",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2de,
	rightIdxPath => ["lookupSrcExt"],
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
);
ok(ref $join2e, "Triceps::LookupJoin");

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

$join2f = Triceps::LookupJoin->new(
	unit => $vu2,
	name => "join2f",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts2de,
	rightIdxPath => ["lookupSrcExt"],
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
	limitOne => 1,
);
ok(ref $join2f, "Triceps::LookupJoin");

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

#########
# test the saveJoinerTo

{
	# not automatic
	my $code;
	my $join = Triceps::LookupJoin->new( 
		unit => $vu2,
		name => "join2ab",
		leftRowType => $rtInTrans,
		rightTable => $tAccounts2,
		rightIdxPath => ["lookupSrcExt"],
		rightFields => [ "internal/acct" ],
		by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
		isLeft => 1,
		automatic => 0,
		saveJoinerTo => \$code,
	);
	ok(ref $join, "Triceps::LookupJoin");
	#print STDERR "code = $code\n";
	ok($code =~ /^\s+sub  # \(\$self, \$row\)/);
}

{
	# automatic
	my $code;
	my $join = Triceps::LookupJoin->new( 
		unit => $vu2,
		name => "join2ab",
		leftRowType => $rtInTrans,
		rightTable => $tAccounts2,
		rightIdxPath => ["lookupSrcExt"],
		rightFields => [ "internal/acct" ],
		by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
		isLeft => 1,
		automatic => 1,
		saveJoinerTo => \$code,
	);
	ok(ref $join, "Triceps::LookupJoin");
	#print STDERR "code = $code\n";
	ok($code =~ /^\s+sub # \(\$inLabel, \$rowop, \$self\)/);
}

#########
# tests for errors

# XXXXXXXXXXX

