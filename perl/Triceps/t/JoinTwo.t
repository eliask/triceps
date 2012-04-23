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
BEGIN { plan tests => 81 };
use Triceps;
use Carp;
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

# this will record the results, per case
my %result;

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
	->addSubIndex("byAccountBackwards", # for joining by account info
		Triceps::IndexType->newHashed(key => [ "acctXtrId", "acctSrc", ])
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

################################################################
# functions that wrap the join creation and wiring

sub wirejoin($$) # (name, join)
{
	my ($name, $join) = @_;

	ok(ref $join, "Triceps::JoinTwo") || confess "join creation failed";

	my $outlab = $vu3->makeLabel($join->getResultRowType(), "out$name", undef, sub { $result{$name} .= $_[1]->printP() . "\n" } );
	ok(ref $outlab, "Triceps::Label") || confess "label creation failed";
	ok($join->getOutputLabel()->chain($outlab));
}

################################################################

# create the joins
# inner
# (also save the joiners)
my($codeLeft, $codeRight);
wirejoin("3a", Triceps::JoinTwo->new(
	name => "join3a",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsUniqKey => "none",
	type => "inner",
	leftSaveJoinerTo => \$codeLeft,
	rightSaveJoinerTo => \$codeRight,
));
ok($codeLeft =~ /^\s+sub # \(\$inLabel, \$rowop, \$self\)/);
ok($codeRight =~ /^\s+sub # \(\$inLabel, \$rowop, \$self\)/);

# outer - with leaf index on left, and fields backwards
wirejoin("3b", Triceps::JoinTwo->new(
	name => "join3b",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsLeftFirst => 0,
	fieldsUniqKey => "none",
	type => "outer",
));

# left
# and along the way test an explicit "by"
wirejoin("3c", Triceps::JoinTwo->new(
	name => "join3c",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccountBackwards"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsUniqKey => "none",
	by => [ 
		"acctXtrId" => "external", 
		"acctSrc" => "source"
	],
	type => "left",
));

# right - with leaf index on left
# and along the way test an explicit "byLeft"
wirejoin("3d", Triceps::JoinTwo->new(
	name => "join3d",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsUniqKey => "none",
	byLeft => [ "acctXtrId/external", "acctSrc/source" ],
	type => "right",
));

# inner - overrideSimpleMinded
wirejoin("3e", Triceps::JoinTwo->new(
	name => "join3e",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsUniqKey => "none",
	type => "inner",
	overrideSimpleMinded => 1,
));

# left - overrideSimpleMinded
wirejoin("3f", Triceps::JoinTwo->new(
	name => "join3f",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsUniqKey => "none",
	type => "left",
	overrideSimpleMinded => 1,
));

# right - overrideSimpleMinded
wirejoin("3g", Triceps::JoinTwo->new(
	name => "join3g",
	leftTable => $tTrans3,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsUniqKey => "none",
	type => "right",
	overrideSimpleMinded => 1,
));

# full outer (same as 3b) but with filtering on the input labels
# (this is a bad example with inconsistent filtering, a good one would filter
# by a key field, same on both sides, by the same condition)

my $lbLeft3h = $vu3->makeDummyLabel($tTrans3p->getRowType(), "lbLeft3h");
my $lbFilterLeft3h = $vu3->makeLabel($tTrans3p->getRowType(), "lbFilterLeft3h", undef, sub {
	my $rowop = $_[1];
	my $row = $rowop->getRow();
	if ($row->get("id") != 1) {
		$vu3->call($lbLeft3h->makeRowop($rowop->getOpcode(), $row));
	}
});
$tTrans3p->getOutputLabel()->chain($lbFilterLeft3h);
my $lbRight3h = $vu3->makeDummyLabel($tAccounts3->getRowType(), "lbRight3h");
my $lbFilterRight3h = $vu3->makeLabel($tAccounts3->getRowType(), "lbFilterRight3h", undef, sub {
	my $rowop = $_[1];
	my $row = $rowop->getRow();
	if ($row->get("external") ne "42") {
		$vu3->call($lbRight3h->makeRowop($rowop->getOpcode(), $row));
	}
});
$tAccounts3->getOutputLabel()->chain($lbFilterRight3h);
wirejoin("3h", Triceps::JoinTwo->new(
	name => "join3h",
	leftTable => $tTrans3p,
	leftFromLabel => $lbLeft3h,
	rightTable => $tAccounts3,
	rightFromLabel => $lbRight3h,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsUniqKey => "none",
	fieldsLeftFirst => 0,
	type => "outer",
));

#########################################################################
# tests of fieldsUniqKey

# full outer (same as 3b) but with fieldsUniqKey==manual
wirejoin("3i", Triceps::JoinTwo->new(
	name => "join3i",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsLeftFirst => 0,
	fieldsUniqKey => "manual",
	type => "outer",
	#leftSaveJoinerTo => \$codeLeft,
	#rightSaveJoinerTo => \$codeRight,
));
#print "left:\n$codeLeft\n";
#print "right:\n$codeRight\n";

# full outer (same as 3b) but with fieldsUniqKey==right
wirejoin("3j", Triceps::JoinTwo->new(
	name => "join3j",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsLeftFirst => 0,
	fieldsUniqKey => "right",
	type => "outer",
	leftSaveJoinerTo => \$codeLeft,
	rightSaveJoinerTo => \$codeRight,
));

# full outer (same as 3b) but with fieldsUniqKey==left
wirejoin("3k", Triceps::JoinTwo->new(
	name => "join3k",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsLeftFirst => 0,
	fieldsUniqKey => "left",
	type => "outer",
	leftSaveJoinerTo => \$codeLeft,
	rightSaveJoinerTo => \$codeRight,
));

# full outer (same as 3b) but with fieldsUniqKey==first and fieldsLeftFirst==0
wirejoin("3l", Triceps::JoinTwo->new(
	name => "join3l",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsLeftFirst => 0,
	fieldsUniqKey => "right",
	type => "outer",
	leftSaveJoinerTo => \$codeLeft,
	rightSaveJoinerTo => \$codeRight,
));

# full outer (same as 3b) but with fieldsUniqKey==first and fieldsLeftFirst==1
wirejoin("3m", Triceps::JoinTwo->new(
	name => "join3m",
	leftTable => $tTrans3p,
	rightTable => $tAccounts3,
	leftIdxPath => ["byAccount"],
	rightIdxPath => ["lookupSrcExt"],
	leftFields => undef, # copy all
	rightFields => [ '.*/ac_$&' ], # copy all with prefix ac_
	fieldsLeftFirst => 1,
	fieldsUniqKey => "left",
	type => "outer",
	leftSaveJoinerTo => \$codeLeft,
	rightSaveJoinerTo => \$codeRight,
));

##########################################################################
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
ok ($result{"3a"}, 
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
ok ($result{"3b"}, 
'join3b.leftLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3b.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3b.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3b.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" 
join3b.rightLookup.out OP_INSERT ac_source="source1" ac_external="42" ac_internal="3" 
join3b.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3b.leftLookup.out OP_DELETE ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3b.leftLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" 
join3b.leftLookup.out OP_INSERT id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3b.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3b.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" 
join3b.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" 
join3b.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3b.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3b.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3b.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3b.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="4" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3b.leftLookup.out OP_DELETE ac_source="source1" ac_external="2011" ac_internal="2" 
join3b.leftLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" id="4" acctSrc="source1" acctXtrId="2011" amount="500" 
');
ok ($result{"3c"}, 
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
ok ($result{"3d"}, 
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
ok ($result{"3e"}, 
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
ok ($result{"3f"}, 
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
ok ($result{"3g"}, 
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
# the result is inconsistent because of the filtering not being consistent
ok ($result{"3h"}, 
'join3h.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3h.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3h.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" 
join3h.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3h.leftLookup.out OP_DELETE ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3h.leftLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" 
join3h.leftLookup.out OP_INSERT id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3h.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" 
join3h.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3h.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3h.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3h.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3h.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="4" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3h.leftLookup.out OP_DELETE ac_source="source1" ac_external="2011" ac_internal="2" 
join3h.leftLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" id="4" acctSrc="source1" acctXtrId="2011" amount="500" 
');
ok ($result{"3i"}, 
'join3i.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3i.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3i.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3i.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" acctSrc="source1" acctXtrId="2011" 
join3i.rightLookup.out OP_INSERT ac_source="source1" ac_external="42" ac_internal="3" acctSrc="source1" acctXtrId="42" 
join3i.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" acctSrc="source2" acctXtrId="ABCD" 
join3i.leftLookup.out OP_DELETE ac_source="source2" ac_external="ABCD" ac_internal="1" acctSrc="source2" acctXtrId="ABCD" 
join3i.leftLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" 
join3i.leftLookup.out OP_INSERT ac_source="source3" ac_external="ZZZZ" id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3i.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3i.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" acctSrc="source1" acctXtrId="999" 
join3i.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" acctSrc="source1" acctXtrId="999" 
join3i.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3i.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3i.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3i.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3i.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="4" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3i.leftLookup.out OP_DELETE ac_source="source1" ac_external="2011" ac_internal="2" acctSrc="source1" acctXtrId="2011" 
join3i.leftLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" id="4" acctSrc="source1" acctXtrId="2011" amount="500" 
');
ok ($result{"3j"}, 
'join3j.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" id="1" amount="100" 
join3j.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" id="1" amount="100" 
join3j.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="1" amount="100" 
join3j.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" 
join3j.rightLookup.out OP_INSERT ac_source="source1" ac_external="42" ac_internal="3" 
join3j.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3j.leftLookup.out OP_DELETE ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3j.leftLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" id="2" amount="200" 
join3j.leftLookup.out OP_INSERT ac_source="source3" ac_external="ZZZZ" id="3" amount="300" 
join3j.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="1" amount="100" 
join3j.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" 
join3j.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" 
join3j.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="4" amount="400" 
join3j.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="4" amount="400" 
join3j.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" id="4" amount="400" 
join3j.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" id="4" amount="400" 
join3j.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="4" id="4" amount="400" 
join3j.leftLookup.out OP_DELETE ac_source="source1" ac_external="2011" ac_internal="2" 
join3j.leftLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" id="4" amount="500" 
');
ok ($result{"3k"}, 
'join3k.leftLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3k.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3k.rightLookup.out OP_INSERT ac_internal="1" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3k.rightLookup.out OP_INSERT ac_internal="2" acctSrc="source1" acctXtrId="2011" 
join3k.rightLookup.out OP_INSERT ac_internal="3" acctSrc="source1" acctXtrId="42" 
join3k.rightLookup.out OP_INSERT ac_internal="1" acctSrc="source2" acctXtrId="ABCD" 
join3k.leftLookup.out OP_DELETE ac_internal="1" acctSrc="source2" acctXtrId="ABCD" 
join3k.leftLookup.out OP_INSERT ac_internal="1" id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" 
join3k.leftLookup.out OP_INSERT id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3k.leftLookup.out OP_DELETE ac_internal="1" id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3k.leftLookup.out OP_INSERT ac_internal="1" acctSrc="source1" acctXtrId="999" 
join3k.leftLookup.out OP_DELETE ac_internal="1" acctSrc="source1" acctXtrId="999" 
join3k.leftLookup.out OP_INSERT ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3k.rightLookup.out OP_DELETE ac_internal="1" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3k.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3k.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3k.rightLookup.out OP_INSERT ac_internal="4" id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3k.leftLookup.out OP_DELETE ac_internal="2" acctSrc="source1" acctXtrId="2011" 
join3k.leftLookup.out OP_INSERT ac_internal="2" id="4" acctSrc="source1" acctXtrId="2011" amount="500" 
');
ok ($result{"3l"}, 
'join3l.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" id="1" amount="100" 
join3l.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" id="1" amount="100" 
join3l.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="1" amount="100" 
join3l.rightLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" 
join3l.rightLookup.out OP_INSERT ac_source="source1" ac_external="42" ac_internal="3" 
join3l.rightLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3l.leftLookup.out OP_DELETE ac_source="source2" ac_external="ABCD" ac_internal="1" 
join3l.leftLookup.out OP_INSERT ac_source="source2" ac_external="ABCD" ac_internal="1" id="2" amount="200" 
join3l.leftLookup.out OP_INSERT ac_source="source3" ac_external="ZZZZ" id="3" amount="300" 
join3l.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="1" amount="100" 
join3l.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" 
join3l.leftLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" 
join3l.leftLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="1" id="4" amount="400" 
join3l.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" ac_internal="1" id="4" amount="400" 
join3l.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" id="4" amount="400" 
join3l.rightLookup.out OP_DELETE ac_source="source1" ac_external="999" id="4" amount="400" 
join3l.rightLookup.out OP_INSERT ac_source="source1" ac_external="999" ac_internal="4" id="4" amount="400" 
join3l.leftLookup.out OP_DELETE ac_source="source1" ac_external="2011" ac_internal="2" 
join3l.leftLookup.out OP_INSERT ac_source="source1" ac_external="2011" ac_internal="2" id="4" amount="500" 
');
ok ($result{"3m"}, 
'join3m.leftLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3m.rightLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" 
join3m.rightLookup.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_internal="1" 
join3m.rightLookup.out OP_INSERT acctSrc="source1" acctXtrId="2011" ac_internal="2" 
join3m.rightLookup.out OP_INSERT acctSrc="source1" acctXtrId="42" ac_internal="3" 
join3m.rightLookup.out OP_INSERT acctSrc="source2" acctXtrId="ABCD" ac_internal="1" 
join3m.leftLookup.out OP_DELETE acctSrc="source2" acctXtrId="ABCD" ac_internal="1" 
join3m.leftLookup.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" ac_internal="1" 
join3m.leftLookup.out OP_INSERT id="3" acctSrc="source3" acctXtrId="ZZZZ" amount="300" 
join3m.leftLookup.out OP_DELETE id="1" acctSrc="source1" acctXtrId="999" amount="100" ac_internal="1" 
join3m.leftLookup.out OP_INSERT acctSrc="source1" acctXtrId="999" ac_internal="1" 
join3m.leftLookup.out OP_DELETE acctSrc="source1" acctXtrId="999" ac_internal="1" 
join3m.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_internal="1" 
join3m.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_internal="1" 
join3m.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3m.rightLookup.out OP_DELETE id="4" acctSrc="source1" acctXtrId="999" amount="400" 
join3m.rightLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="999" amount="400" ac_internal="4" 
join3m.leftLookup.out OP_DELETE acctSrc="source1" acctXtrId="2011" ac_internal="2" 
join3m.leftLookup.out OP_INSERT id="4" acctSrc="source1" acctXtrId="2011" amount="500" ac_internal="2" 
');
#print STDERR $result3i;

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
