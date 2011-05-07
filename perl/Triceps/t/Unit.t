#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for Unit.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 17 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


###################### new #################################

$u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

###################### makeTable prep #################################

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
	->addNested("fifo", Triceps::IndexType->newFifo()
	);
ok(ref $it1, "Triceps::IndexType");

$tt1 = Triceps::TableType->new($rt1)
	->addIndex("grouping", $it1);
ok(ref $tt1, "Triceps::TableType");

# check with uninitialized type
$t1 = $u1->makeTable($tt1, "SM_SCHEDULE", "tab1");
ok(!defined $t1);
ok($! . "", "Triceps::Unit::makeTable: table type was not successfully initialized");

$res = $tt1->initialize();
ok($res, 1);
print STDERR "$!" . "\n";

###################### makeTable #################################

$t1 = $u1->makeTable($tt1, "SM_SCHEDULE", "tab1");
ok(ref $t1, "Triceps::Table");
#print STDERR "$!" . "\n";

$t1 = $u1->makeTable($tt1, "SM_FORK", "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, "SM_CALL", "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, "SM_IGNORE", "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, 0, "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, 0.0, "tab1");
ok(!defined $t1);
ok($! . "", "Triceps::Unit::makeTable: unknown enqueuing mode string '0', if integer was meant, it has to be cast");

$t1 = $u1->makeTable($tt1, 20, "tab1");
ok(!defined $t1);
ok($! . "", "Triceps::Unit::makeTable: unknown enqueuing mode integer 20");
