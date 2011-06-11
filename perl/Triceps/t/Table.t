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
BEGIN { plan tests => 15 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


######################### preparations (originating from Unit.t)  #############################

$u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

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
