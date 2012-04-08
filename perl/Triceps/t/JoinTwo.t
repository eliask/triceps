#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A test of join between two tables.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 55 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# (continues the discussion from LookupJoin)
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

############################# accounts table definition ###########################
# (copied from LookupJoin.t)

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

#######################################################################
# 3. A table-to-table join.
# It's the next step of complexity that still has serious limitations:
# joining only two tables, and no self-joins.
# It's implemented in a simple way by tying together 2 LookupJoins.

# XXX test Triceps::JoinTwo for errors

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
my $join3a = Triceps::JoinTwo->new(
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
ok(ref $join3a, "Triceps::JoinTwo");

my $outlab3a = $vu3->makeLabel($join3a->getResultRowType(), "out3a", undef, sub { $result3a .= $_[1]->printP() . "\n" } );
ok(ref $outlab3a, "Triceps::Label");
ok($join3a->getOutputLabel()->chain($outlab3a));

# outer - with leaf index on left
my $join3b = Triceps::JoinTwo->new(
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
ok(ref $join3b, "Triceps::JoinTwo");

my $outlab3b = $vu3->makeLabel($join3b->getResultRowType(), "out3b", undef, sub { $result3b .= $_[1]->printP() . "\n" } );
ok(ref $outlab3b, "Triceps::Label");
ok($join3b->getOutputLabel()->chain($outlab3b));

# left
my $join3c = Triceps::JoinTwo->new(
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
ok(ref $join3c, "Triceps::JoinTwo");

my $outlab3c = $vu3->makeLabel($join3c->getResultRowType(), "out3c", undef, sub { $result3c .= $_[1]->printP() . "\n" } );
ok(ref $outlab3c, "Triceps::Label");
ok($join3c->getOutputLabel()->chain($outlab3c));

# right - with leaf index on left
my $join3d = Triceps::JoinTwo->new(
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
ok(ref $join3d, "Triceps::JoinTwo");

my $outlab3d = $vu3->makeLabel($join3d->getResultRowType(), "out3d", undef, sub { $result3d .= $_[1]->printP() . "\n" } );
ok(ref $outlab3d, "Triceps::Label");
ok($join3d->getOutputLabel()->chain($outlab3d));

# inner - simpleMinded
my $join3e = Triceps::JoinTwo->new(
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
ok(ref $join3e, "Triceps::JoinTwo");

my $outlab3e = $vu3->makeLabel($join3e->getResultRowType(), "out3e", undef, sub { $result3e .= $_[1]->printP() . "\n" } );
ok(ref $outlab3e, "Triceps::Label");
ok($join3e->getOutputLabel()->chain($outlab3e));

# left - simpleMinded
my $join3f = Triceps::JoinTwo->new(
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
ok(ref $join3f, "Triceps::JoinTwo");

my $outlab3f = $vu3->makeLabel($join3f->getResultRowType(), "out3f", undef, sub { $result3f .= $_[1]->printP() . "\n" } );
ok(ref $outlab3f, "Triceps::Label");
ok($join3f->getOutputLabel()->chain($outlab3f));

# right - simpleMinded
my $join3g = Triceps::JoinTwo->new(
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
ok(ref $join3g, "Triceps::JoinTwo");

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
