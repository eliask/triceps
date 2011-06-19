#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for Table.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 86 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


######################### preparations (originating from Unit.t)  #############################

$u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

$u2 = Triceps::Unit->new("u2");
ok(ref $u2, "Triceps::Unit");

@def1 = (
	a => "uint8",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
$rt1 = Triceps::RowType->new( # used later
	@def1
);
ok(ref $rt1, "Triceps::RowType");

$it1 = Triceps::IndexType->newHashed(key => [ "b", "c" ])
	->addSubIndex("fifo", Triceps::IndexType->newFifo()
	);
ok(ref $it1, "Triceps::IndexType");

$tt1 = Triceps::TableType->new($rt1)
	->addSubIndex("grouping", $it1);
ok(ref $tt1, "Triceps::TableType");

$res = $tt1->initialize();
ok($res, 1);
#print STDERR "$!" . "\n";

$t1 = $u1->makeTable($tt1, "EM_SCHEDULE", "tab1");
ok(ref $t1, "Triceps::Table");

### table 2 with a different type

@def2 = (
	a => "uint8[]",
	b => "int32[]",
	c => "int64[]",
	d => "float64[]",
	e => "string",
);
$rt2 = Triceps::RowType->new( # used later
	@def2
);
ok(ref $rt2, "Triceps::RowType");

$tt2 = Triceps::TableType->new($rt2)
	->addSubIndex("grouping", Triceps::IndexType->newHashed(key => [ "b", "c" ]) ); 
ok(ref $tt2, "Triceps::TableType");

$res = $tt2->initialize();
ok($res, 1);

$t2 = $u1->makeTable($tt2, "EM_SCHEDULE", "tab2");
ok(ref $t2, "Triceps::Table");

########################## basic functions #################################################

# currently there is no way to get 2 different refs to the same table
$res = $t1->same($t1);
ok($res);

$res = $t1->same($t2);
ok(!$res);

$res = $t1->getName();
ok($res, "tab1");

$rtt = $t1->getRowType();
ok(ref $rtt, "Triceps::RowType");
ok($rt1->same($rtt));

$res = $t1->size();
ok($res, 0); # no data in the table yet

########################## get label #################################################

$lb = $t1->getInputLabel();
ok(ref $lb, "Triceps::Label");

$lb = $t1->getOutputLabel();
ok(ref $lb, "Triceps::Label");

$res = $t1->getUnit();
ok(ref $res, "Triceps::Unit");

################# getting back and sameness of various objects  ##############################
# sameness tested here because a table is a convenient way to get back another reference to
# existing objects

$tt2 = $t1->getType();
ok($tt1->same($tt2));

# copying of types after initialization
$it3 = $tt1->findSubIndex("grouping");
ok(ref $it3, "Triceps::IndexType");
ok($it3->isInitialized());
$it4 = $it3->copy();
ok(ref $it4, "Triceps::IndexType");
ok(!$it4->isInitialized());

########################## makeRowHandle  #################################################

@dataset1 = (
	a => "uint8",
	b => 123,
	c => 3e15+0,
	d => 3.14,
	e => "string",
);
$r1 = $rt1->makeRowHash( @dataset1);
ok(ref $r1, "Triceps::Row");

@dataset2 = (
	a => "uint8",
	b => [ 123 ],
	c => [ 3e15+0 ],
	d => [ 3.14 ],
	e => "string",
);
$r2 = $rt2->makeRowHash( @dataset2);
ok(ref $r2, "Triceps::Row");

$rh1 = $t1->makeRowHandle($r1);
ok(ref $rh1, "Triceps::RowHandle");

$rh2 = $t1->makeRowHandle($r2);
ok(!defined $rh2);
ok($! . "", "Triceps::Table::makeRowHandle: table and row types are not equal, in table: row { uint8 a, int32 b, int64 c, float64 d, string e, }, in row: row { uint8[] a, int32[] b, int64[] c, float64[] d, string e, }");

$rh2 = $t2->makeRowHandle($r2);
ok(ref $rh2, "Triceps::RowHandle");

########################## tests of RowHandle  #################################################

# XXX test RowHandle::same() later
$res = $rh1->isInTable();
ok(!$res);

$res = $rh1->getRow();
ok(ref $res, "Triceps::Row");
ok($r1->same($res));

########################## basic ops  #################################################

# insert
$res = $t1->insert($rh1);
ok($res == 1);
$res = $t1->size();
ok($res, 1);
$res = $rh1->isInTable();
ok($res);

# inserting the same row 2nd time returns 0
$res = $t1->insert($rh1);
ok($res == 0);
ok(defined $res);

# insert a Row directly
$res = $t1->insert($r1);
ok($res == 1);
$res = $t1->size();
ok($res, 2); # they get collected in a FIFO

# with copyTray: more interesting if the rows get replaced

$ctr = $u1->makeTray();
ok(ref $ctr, "Triceps::Tray");

$res = $t2->insert($r2, $ctr);
ok($res == 1);
$res = $t2->size();
ok($res, 1);
$res = $ctr->size();
ok($res, 1);
@arr = $ctr->toArray();
ok($arr[0]->getOpcode(), &Triceps::OP_INSERT);
ok($r2->same($arr[0]->getRow()));

$ctr->clear();
ok($ctr->size(), 0);
$res = $t2->insert($rh2, $ctr);
ok($res == 1);
$res = $t2->size();
ok($res, 1); # old record gets pushed out
ok($ctr->size(), 2); # both delete and insert
@arr = $ctr->toArray();
ok($arr[0]->getOpcode(), &Triceps::OP_DELETE);
ok($r2->same($arr[0]->getRow()));
ok($arr[1]->getOpcode(), &Triceps::OP_INSERT);
ok($r2->same($arr[1]->getRow()));

# bad args
$res = $t1->insert(0);
ok(!defined $res);
ok($! . "", "Triceps::Table::insert: row argument is not a blessed SV reference to Row or RowHandle");

$res = $t1->insert($t2);
ok(!defined $res);
ok($! . "", "Triceps::Table::insert: row argument has an incorrect magic for Row or RowHandle");

$res = $t1->insert($r2);
ok(!defined $res);
ok($! . "", "Triceps::Table::insert: table and row types are not equal, in table: row { uint8 a, int32 b, int64 c, float64 d, string e, }, in row: row { uint8[] a, int32[] b, int64[] c, float64[] d, string e, }");

$res = $t1->insert($rh2);
ok(!defined $res);
ok($! . "", "Triceps::Table::insert: row argument is a RowHandle in a wrong table tab2");

$res = $t1->insert($rh1, 0);
ok(!defined $res);
ok($! . "", "Triceps::Table::insert: copyTray is not a blessed SV reference to WrapTray");

$res = $t1->insert($rh1, $t2);
ok(!defined $res);
ok($! . "", "Triceps::Table::insert: copyTray has an incorrect magic for WrapTray");

$ctr2 = $u2->makeTray();
$res = $t1->insert($rh1, $ctr2);
ok(!defined $res);
ok($! . "", "Triceps::Table::insert: copyTray is from a wrong unit u2, table in unit u1");

# remove
$res = $t1->remove($rh1);
ok($res, 1);
$res = $t1->size();
ok($res, 1);
$res = $rh1->isInTable();
ok(!$res);

# remove with copyTray
$ctr->clear();
ok($rh2->isInTable());
$res = $t2->remove($rh2, $ctr);
ok($res, 1);
ok(!$rh2->isInTable());
$res = $t2->size();
ok($res, 0);
$res = $ctr->size();
ok($res, 1);
@arr = $ctr->toArray();
ok($arr[0]->getOpcode(), &Triceps::OP_DELETE);
ok($r2->same($arr[0]->getRow()));

# attempt to remove a row not in table
$ctr->clear();
$res = $t2->remove($rh2, $ctr);
ok($res, 1);
$res = $ctr->size();
ok($res, 0);

# bad args
$res = $t1->remove($rh2);
ok(!defined $res);
ok($! . "", "Triceps::Table::remove: row argument is a RowHandle in a wrong table tab2");

$ctr2 = $u2->makeTray();
$res = $t1->remove($rh1, $ctr2);
ok(!defined $res);
ok($! . "", "Triceps::Table::remove: copyTray is from a wrong unit u2, table in unit u1");

