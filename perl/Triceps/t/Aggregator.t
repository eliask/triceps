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
BEGIN { plan tests => 22 };
use Triceps;
ok(2); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


######################### preparations (originating from Unit.t and Table.t)  #############################

$u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

# for debugging
$trsn1 = Triceps::UnitTracerStringName->new();
ok(ref $trsn1, "Triceps::UnitTracerStringName");
$u1->setTracer($trsn1);
ok($! . "", "");

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

######################### basic aggregation  #############################

# collect the aggregator handler call history
my $aggistory;

sub aggHandler # (table, context, aggop, opcode, rh, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, @args) = @_;
	$agghistory .= "bad context type " . ref($context) unless (ref($context) eq "Triceps::AggregatorContext");
	$_[1] = 99; # try to spoil the original reference to context

	$agghistory .= "call (" . join(", ", @args) . ") " . &Triceps::aggOpString($aggop) . " " . &Triceps::opcodeString($opcode);
	my $row = $rh->getRow();
	if (defined $row) {
		$agghistory .= " [" . join(", ", $rh->getRow()->toArray()) . "]\n";
	} else {
		$agghistory .= " NULL\n";
	}

	# calculate b as count(*), c as sum(c), v as last(d)
	my $sum = 0;
	my $lastrh;
	for (my $iterh = $context->begin(); !$iterh->isNull(); $iterh = $context->next($iterh)) {
		$lastrh = $iterh;
		$sum += $iterh->getRow()->get("c");
	}

	my @vals = ( b => $context->groupSize(), c => $sum, v => $lastrh->getRow()->get("d") );
	my $res = $context->resultType()->makeRowHash(@vals);
	$context->send($opcode, $res);
	#print STDERR "DEBUG sent agg result [" . join(", ", $res->toArray()) . "]\n";

	undef $context; # if the references are wrong, this would delete the context object and cause a valgrind error later
}

# collect the aggregator result history
my $reshistory;

sub append_reshistory
{
	#print STDERR "DEBUG append_reshistory\n";
	my $lab = shift;
	my $rop = shift;
	$reshistory .= &Triceps::opcodeString($rop->getOpcode()) . " " 
		. " [" . join(", ", $rop->getRow()->toArray()) . "]\n";
}

my $aggreslab1 = $u1->makeLabel($rt2, "aggres1", \&append_reshistory);
ok(ref $aggreslab1, "Triceps::Label");

$agt1 = Triceps::AggregatorType->new($rt2, "aggr", undef, \&aggHandler, "qqqq", 12);
ok(ref $agt1, "Triceps::AggregatorType");

$it1 = Triceps::IndexType->newHashed(key => [ "b", "c" ])
	->addSubIndex("fifo", Triceps::IndexType->newFifo()
		->setAggregator($agt1)
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

# connect the history recording label
$res = $t1->getAggregatorLabel("aggr");
ok(ref $res, "Triceps::Label");
$res = $res->chain($aggreslab1);
ok($res, 1);

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

ok($agghistory, 
	"call (qqqq, 12) AO_AFTER_INSERT OP_INSERT [uint8, 123, 3000000000000000, 3.14, string]\n"
	. "call (qqqq, 12) AO_BEFORE_MOD OP_DELETE NULL\n"
	. "call (qqqq, 12) AO_AFTER_INSERT OP_INSERT [aaa, 123, 3000000000000000, 2.71, string2]\n");

# for the results to propagate through the history label, the unit must run...
$u1->drainFrame();
ok($u1->empty());
#print STDERR "DEBUG trace:\n" . $trsn1->print();

ok($reshistory, 
	"OP_INSERT  [1, 3000000000000000, 3.14]\n"
	. "OP_DELETE  [1, 3000000000000000, 3.14]\n"
	. "OP_INSERT  [2, 6000000000000000, 2.71]\n");

# XXX test context invalidation
# XXX example with keeping the state!

