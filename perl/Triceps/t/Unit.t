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
BEGIN { plan tests => 57 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


###################### new #################################

$u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

$u2 = Triceps::Unit->new("u2");
ok(ref $u2, "Triceps::Unit");

$v = $u1->same($u1);
ok($v);
$v = $u1->same($u2);
ok(!$v);

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
$t1 = $u1->makeTable($tt1, "EM_SCHEDULE", "tab1");
ok(!defined $t1);
ok($! . "", "Triceps::Unit::makeTable: table type was not successfully initialized");

$res = $tt1->initialize();
ok($res, 1);
#print STDERR "$!" . "\n";

###################### makeTable #################################

$t1 = $u1->makeTable($tt1, "EM_SCHEDULE", "tab1");
ok(ref $t1, "Triceps::Table");
#print STDERR "$!" . "\n";

$v = $t1->getUnit();
ok($u1->same($v));

$t1 = $u1->makeTable($tt1, "EM_FORK", "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, "EM_CALL", "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, "EM_IGNORE", "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, 0, "tab1");
ok(ref $t1, "Triceps::Table");

$t1 = $u1->makeTable($tt1, 0.0, "tab1");
ok(!defined $t1);
ok($! . "", "Triceps::Unit::makeTable: unknown enqueuing mode string '0', if integer was meant, it has to be cast");

$t1 = $u1->makeTable($tt1, 20, "tab1");
ok(!defined $t1);
ok($! . "", "Triceps::Unit::makeTable: unknown enqueuing mode integer 20");

###################### makeTray #################################
# see in Tray.t

###################### make*Label ###############################

sub exe_history # (label, rowop)
{
	my ($label, $rowop) = @_;
	our $history;
	$history .= "x " . $label->getName() . " op=" . Triceps::opcodeString($rowop->getOpcode()) 
		. " row=[" . join(", ", $rowop->getRow()->to_ar()) . "]\n";
}

sub exe_die # (label, rowop)
{
	my ($label, $rowop) = @_;
	die "xdie " . $label->getName() . " op=" . Triceps::opcodeString($rowop->getOpcode()) 
		. " row=[" . join(", ", $rowop->getRow()->to_ar()) . "]";
}

$dumlab = $u1->makeDummyLabel($rt1, "dumlab");
ok(ref $dumlab, "Triceps::Label");

$xlab1 = $u1->makeLabel($rt1, "xlab1", \&exe_history);
ok(ref $xlab1, "Triceps::Label");
$xlab2 = $u1->makeLabel($rt1, "xlab2", \&exe_history);
ok(ref $xlab2, "Triceps::Label");

$dielab = $u1->makeLabel($rt1, "dielab", \&exe_die);
ok(ref $dielab, "Triceps::Label");

$v = $dumlab->chain($xlab2);
ok($v);

$history = "";

# prepare rowops for enqueueing

@dataset1 = (
	a => 123,
	b => 456,
	c => 789,
	d => 3.14,
	e => "text",
);
$row1 = $rt1->makerow_hs(@dataset1);
ok(ref $row1, "Triceps::Row");

$rop11 = $xlab1->makeRowop("OP_INSERT", $row1);
ok(ref $rop11, "Triceps::Rowop");
$rop12 = $xlab1->makeRowop("OP_DELETE", $row1);
ok(ref $rop12, "Triceps::Rowop");

# will get to xlab2 through the chaining
$rop21 = $dumlab->makeRowop("OP_INSERT", $row1);
ok(ref $rop21, "Triceps::Rowop");
$rop22 = $dumlab->makeRowop("OP_DELETE", $row1);
ok(ref $rop22, "Triceps::Rowop");
# put them into a tray
$tray2 = $u1->makeTray($rop21, $rop22);
ok(ref $tray2, "Triceps::Tray");

$ropd1 = $dielab->makeRowop("OP_INSERT", $row1);
ok(ref $ropd1, "Triceps::Rowop");
$ropd2 = $dielab->makeRowop("OP_DELETE", $row1);
ok(ref $ropd2, "Triceps::Rowop");

# also add an empty tray
$trayem = $u1->makeTray();
ok(ref $trayem, "Triceps::Tray");

##################### schedule ##################################

# schedule 

$v = $u1->empty();
ok($v);

$v = $u1->schedule($rop11, $tray2, $rop12, $trayem);
ok($v);
#print STDERR $! . "\n";

$v = $u1->empty();
ok(!$v);

$history = "";
$u1->callNext();
ok($history, "x xlab1 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n");

$history = "";
$u1->callNext();
ok($history, "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n");

$history = "";
$u1->drainFrame();
ok($history, "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text]\nx xlab1 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n");
$v = $u1->empty();
ok($v);

# fork

$v = $u1->fork($rop11, $tray2, $rop12, $trayem);
ok($v);
$v = $u1->empty();
ok(!$v);
$history = "";
$u1->drainFrame();
ok($history, 
	  "x xlab1 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n" 
	. "x xlab1 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n");
$v = $u1->empty();
ok($v);

# call

$history = "";
$v = $u1->call($rop11, $tray2, $rop12, $trayem);
ok($v);
# no drain, CALL gets executed immediately
ok($history, 
	  "x xlab1 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n" 
	. "x xlab1 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n");
$v = $u1->empty();
ok($v);

# enqueue with constant

$v = $u1->enqueue(&Triceps::EM_FORK, $rop11, $tray2, $rop12, $trayem);
ok($v);
$v = $u1->empty();
ok(!$v);
$history = "";
$u1->drainFrame();
ok($history, 
	  "x xlab1 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n" 
	. "x xlab1 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n");
$v = $u1->empty();
ok($v);

# enqueue with string

$v = $u1->enqueue("EM_SCHEDULE", $rop11, $tray2, $rop12, $trayem);
ok($v);
$v = $u1->empty();
ok(!$v);
$history = "";
$u1->drainFrame();
ok($history, 
	  "x xlab1 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n" 
	. "x xlab1 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n");
$v = $u1->empty();
ok($v);

# XXX test scheduling for errors
# XXX test that the execution order in scheduling is correct - as in t_Unit.cpp
# XXX test scheduling of dying function
