#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for Rowop.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 11 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


######################### preparations (originating from Label.t)  #############################

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
	->addNested("fifo", Triceps::IndexType->newFifo()
	);
ok(ref $it1, "Triceps::IndexType");

$tt1 = Triceps::TableType->new($rt1)
	->addIndex("grouping", $it1);
ok(ref $tt1, "Triceps::TableType");

$res = $tt1->initialize();
ok($res, 1);
print STDERR "$!" . "\n";

$t1 = $u1->makeTable($tt1, "SM_SCHEDULE", "tab1");
ok(ref $t1, "Triceps::Table");

$lb = $t1->getInputLabel();
ok(ref $lb, "Triceps::Label");

# create a row for Rowop building
@dataset = (
	a => 123,
	b => 456,
	c => 3e15+0,
	d => 3.14,
	e => "text",
);
$row1 = $rt1->makerow_hs(@dataset);
ok(ref $row1, "Triceps::Row");

######################### factory  #############################

$rop = $lb->makeRowop("OP_INSERT", $row1);
ok(ref $rop, "Triceps::Rowop");

$rop = $lb->makeRowop(&Triceps::OP_INSERT, $row1);
ok(ref $rop, "Triceps::Rowop");
