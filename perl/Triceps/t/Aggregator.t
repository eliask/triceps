#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for Aggregator in a table.

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


######################### preparations (originating from Unit.t and Table.t)  #############################

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

@def2 = (
	b => "int32",
	c => "int64",
	v => "float64",
);
$rt2 = Triceps::RowType->new( # used later
	@def2
);
ok(ref $rt2, "Triceps::RowType");

# XXX for now the aggregator doesn't do anyting useful because intermediate types are missing
# collect the aggregator handler call history
my $aggistory;

sub aggHandler # (table, gadget, index, parentIndexType, gh, dest, aggop, opcode, rh, copyTray, args...)
{
	my ($table, $gadget, $index, $parentIndexType, $gh, $dest, $aggop, $opcode, $rh, $copyTray, @args) = @_;
	$agghistory .= "call (" . join(", ", @args) . ") " . &Triceps::opcodeString($opcode);
	my $row = $rh->getRow();
	if (defined $row) {
		$agghistory .= " [" . join(", ", $rh->getRow()->toArray()) . "]\n";
	} else {
		$agghistory .= " NULL\n";
	}
}

$agt1 = Triceps::AggregatorType->new($rt2, "aggr", undef, \&aggHandler, "qqqq", 12);
ok(ref $agt1, "Triceps::AggregatorType");

$it1 = Triceps::IndexType->newHashed(key => [ "b", "c" ])
	->setAggregator($agt1)
	->addSubIndex("fifo", Triceps::IndexType->newFifo()
	);
ok(ref $it1, "Triceps::IndexType");

# XXX the API is not very good: the index can be reused multiple times
# in the same table with different ids, but the aggregator in it can't
$tt1 = Triceps::TableType->new($rt1)
	->addSubIndex("grouping", $it1)
	;
ok(ref $tt1, "Triceps::TableType");

$res = $tt1->initialize();
ok($res, 1);
#print STDERR "$!" . "\n";

$t1 = $u1->makeTable($tt1, "EM_SCHEDULE", "tab1");
ok(ref $t1, "Triceps::Table");

# send some records into the table

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
	a => "aaa",
	b => 123,
	c => 3e15+0,
	d => 2.71,
	e => "string2",
);
$r2 = $rt1->makeRowHash( @dataset2);
ok(ref $r2, "Triceps::Row");

$res = $t1->insert($r1);
ok($res == 1);
$res = $t1->insert($r2);
ok($res == 1);

ok($agghistory, "call (qqqq, 12) OP_INSERT [uint8, 123, 3000000000000000, 3.14, string]\ncall (qqqq, 12) OP_DELETE NULL\ncall (qqqq, 12) OP_INSERT [aaa, 123, 3000000000000000, 2.71, string2]\n");
