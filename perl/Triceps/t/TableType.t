#
# This file is a part of Biceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for TableType.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 29 };
use Biceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

@def1 = (
	a => "uint8",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
$rt1 = Biceps::RowType->new( # used later
	@def1
);
ok(ref $rt1, "Biceps::RowType");

$it1 = Biceps::IndexType->newHashed(key => [ "b", "c" ])
	->addNested("fifo", Biceps::IndexType->newFifo()
	);
ok(ref $it1, "Biceps::IndexType");

###################### new #################################

$tt1 = Biceps::TableType->new($rt1);
ok(ref $tt1, "Biceps::TableType");

$ret = $tt1->rowType();
ok(ref $ret, "Biceps::RowType");

###################### addIndex #################################

# tt2 actually refers to the same C++ object as tt1
$tt2 = $tt1->addIndex("primary", $it1);
ok(ref $tt2, "Biceps::TableType");


$tt3 = Biceps::TableType->new($rt1)
	->addIndex("primary", $it1);
ok(ref $tt3, "Biceps::TableType");

###################### equals #################################

$res = $tt1->equals($tt2);
ok($res);
$res = $tt1->match($tt2);
ok($res);

$res = $tt1->match($tt3);
ok($res);
$res = $tt1->equals($tt3);
ok($res);

$tt1->addIndex("second", Biceps::IndexType->newFifo());
# they still point to the same object!
$res = $tt1->equals($tt2);
ok($res);

$res = $tt1->match($tt3);
ok(!$res);

$res = $tt1->same($tt2);
ok($res);
$res = $tt1->same($tt3);
ok(!$res);

###################### print #################################

$res = $tt1->print();
ok($res, "table (\n  row {\n    uint8 a,\n    int32 b,\n    int64 c,\n    float64 d,\n    string e,\n  }\n) {\n  HashedIndex(b, c, ) {\n    FifoIndex() fifo,\n  } primary,\n  FifoIndex() second,\n}");

###################### find #################################

$it2 = $tt1->firstLeafIndex();
$res = $it2->print();
ok($res, "FifoIndex()");

$it2 = $tt1->findIndex("primary");
$res = $it2->print();
ok($res, "HashedIndex(b, c, ) {\n  FifoIndex() fifo,\n}");

$it2 = $tt1->findIndex("xxx");
ok(!defined($it2));

$tt4 = Biceps::TableType->new($rt1);
$it2 = $tt4->firstLeafIndex();
ok(!defined($it2));

###################### initialization #################################

$res = $tt1->isInitialized();
ok($res, 0);

$res = $tt1->initialize();
ok($res, 1);
ok($! . "", "");

$res = $tt1->isInitialized();
ok($res, 1);

# repeated initialization is OK
$res = $tt1->initialize();
ok($res, 1);
ok($! . "", "");

# check that still can find indexes
$it2 = $tt1->firstLeafIndex();
$res = $it2->print();
ok($res, "FifoIndex()");

# adding indexes is not allowed any more
$res = $tt1->addIndex("second", Biceps::IndexType->newFifo());
ok(!defined $res);
ok($! . "", "Biceps::TableType::addIndex: table is already initialized, can not add indexes any more");

