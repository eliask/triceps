#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for Unit.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 124 };
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

###################### name setting #################################

$u2->setName("unit2");
$v = $u2->getName();
ok($v, "unit2");

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
	->addSubIndex("fifo", Triceps::IndexType->newFifo()
	);
ok(ref $it1, "Triceps::IndexType");

$tt1 = Triceps::TableType->new($rt1)
	->addSubIndex("grouping", $it1);
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

my $clearlog; # where the clear function would write its history

sub exe_history # (label, rowop)
{
	my ($label, $rowop) = @_;
	our $history;
	$history .= "x " . $label->getName() . " op=" . Triceps::opcodeString($rowop->getOpcode()) 
		. " row=[" . join(", ", $rowop->getRow()->toArray()) . "]\n";
}

sub exe_history_xargs # (label, rowop, args...)
{
	my $label = shift @_;
	my $rowop = shift @_;
	our $history;
	$history .= "x " . $label->getName() . " op=" . Triceps::opcodeString($rowop->getOpcode()) 
		. " row=[" . join(", ", $rowop->getRow()->toArray()) . "] args=[" . join(',', @_) . "]\n";
}

sub exe_die # (label, rowop)
{
	my ($label, $rowop) = @_;
	die "xdie " . $label->getName() . " op=" . Triceps::opcodeString($rowop->getOpcode()) 
		. " row=[" . join(", ", $rowop->getRow()->toArray()) . "]";
}

sub log_clear # (label, args)
{
	my $label = shift @_;
	$clearlog .= "clear " . $label->getName() . " args=["  . join(",", @_) . "]\n";
}

$dumlab = $u1->makeDummyLabel($rt1, "dumlab");
ok(ref $dumlab, "Triceps::Label");

$xlab1 = $u1->makeLabel($rt1, "xlab1", \&log_clear, \&exe_history);
ok(ref $xlab1, "Triceps::Label");
$xlab2 = $u1->makeLabel($rt1, "xlab2", \&log_clear, \&exe_history_xargs, "a", "b");
ok(ref $xlab2, "Triceps::Label");

$dielab = $u1->makeLabel($rt1, "dielab", undef, \&exe_die);
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
$row1 = $rt1->makeRowHash(@dataset1);
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
ok($history, "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text] args=[a,b]\n");

$history = "";
$u1->drainFrame();
ok($history, "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text] args=[a,b]\nx xlab1 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n");
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
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text] args=[a,b]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text] args=[a,b]\n" 
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
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text] args=[a,b]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text] args=[a,b]\n" 
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
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text] args=[a,b]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text] args=[a,b]\n" 
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
	. "x xlab2 op=OP_INSERT row=[123, 456, 789, 3.14, text] args=[a,b]\n"
	. "x xlab2 op=OP_DELETE row=[123, 456, 789, 3.14, text] args=[a,b]\n" 
	. "x xlab1 op=OP_DELETE row=[123, 456, 789, 3.14, text]\n");
$v = $u1->empty();
ok($v);

#############################################################
# test scheduling for error catching

$elab1 = $u1->makeLabel($rt1, "elab1", undef, sub { die "an error in label handler" } );
ok(ref $elab1, "Triceps::Label");

$erop = $elab1->makeRowop("OP_INSERT", $row1);
ok(ref $erop, "Triceps::Rowop");

print STDERR "Expect error message from unit u1 label elab1 handler\n";
$v = $u1->schedule($erop);
$u1->drainFrame();
ok($v);

$v = $u1->call($rop11);
$xlab1->clear(); # now the label could not call anything any more
$v = $u1->call($rop11);
ok(!defined $v);
ok("$!", "Triceps::Unit::call: argument 1 is a Rowop for label xlab1 from a wrong unit [label cleared]");
ok($clearlog, "clear xlab1 args=[]\n");

#############################################################
# tracer ops

$v = $u1->getTracer();
ok(! defined $v);
ok($! . "", "");

$trsn1 = Triceps::UnitTracerStringName->new();
ok(ref $trsn1, "Triceps::UnitTracerStringName");

$u1->setTracer($trsn1);
$v = $u1->getTracer();
ok(ref $v, "Triceps::UnitTracerStringName");
ok($trsn1->same($v));

$trp1 = Triceps::UnitTracerPerl->new(sub {});
ok(ref $trp1, "Triceps::UnitTracerPerl");

$u1->setTracer($trp1);
$v = $u1->getTracer();
ok(ref $v, "Triceps::UnitTracerPerl");
ok($trp1->same($v));

$u1->setTracer(undef);
ok($! . "", "");

$v = $u1->getTracer();
ok(! defined $v);
ok($! . "", "");

# try to set an invalid value
$u1->setTracer(10);
ok($! . "", "Unit::setTracer: tracer is not a blessed SV reference to WrapUnitTracer");

$u1->setTracer($u1);
ok($! . "", "Unit::setTracer: tracer has an incorrect magic for WrapUnitTracer");

#############################################################
# test all 3 kinds of scheduling for correct functioning - as in t_Unit.cpp scheduling()
# uses UnitTracerStringName and UnitTracerPerl, so tests them too

if (0) {
sub exe_call_two # (label, rowop, sub1, sub2)
{
	my ($label, $rowop, $sub1, $sub2) = @_;
	my $unit = $label->getUnit();
	$unit->call($sub1);
	$unit->enqueue(&Triceps::EM_CALL, $sub2);
}

sub exe_fork_two # (label, rowop, sub1, sub2)
{
	my ($label, $rowop, $sub1, $sub2) = @_;
	my $unit = $label->getUnit();
	$unit->fork($sub1);
	$unit->enqueue(&Triceps::EM_FORK, $sub2);
}

sub exe_sched_two # (label, rowop, sub1, sub2)
{
	my ($label, $rowop, $sub1, $sub2) = @_;
	my $unit = $label->getUnit();
	$unit->schedule($sub1);
	$unit->enqueue(&Triceps::EM_SCHEDULE, $sub2);
}
} # 0

sub exe_sched_fork_call # (label, rowop, lab1, lab2, lab3, row)
{
	my ($label, $rowop, $lab1, $lab2, $lab3, $row) = @_;
	my $unit = $label->getUnit();
	$unit->schedule($lab1->makeRowop(&Triceps::OP_INSERT, $row));
	$unit->schedule($lab1->makeRowop(&Triceps::OP_DELETE, $row));
	$unit->fork($lab2->makeRowop(&Triceps::OP_INSERT, $row));
	$unit->fork($lab2->makeRowop(&Triceps::OP_DELETE, $row));
	$unit->call($lab3->makeRowop(&Triceps::OP_INSERT, $row));
	$unit->call($lab3->makeRowop(&Triceps::OP_DELETE, $row));
}

$sntr = Triceps::UnitTracerStringName->new();
$u1->setTracer($sntr);
ok($! . "", "");

$s_lab1 = $u1->makeDummyLabel($rt1, "lab1");
ok(ref $s_lab1, "Triceps::Label");
$s_lab2 = $u1->makeDummyLabel($rt1, "lab2");
ok(ref $s_lab2, "Triceps::Label");
$s_lab3 = $u1->makeDummyLabel($rt1, "lab3");
ok(ref $s_lab3, "Triceps::Label");

$s_lab4 = $u1->makeLabel($rt1, "lab4", undef, \&exe_sched_fork_call, $s_lab1, $s_lab2, $s_lab3, $row1);
ok(ref $s_lab4, "Triceps::Label");
$s_lab5 = $u1->makeLabel($rt1, "lab5", undef, \&exe_sched_fork_call, $s_lab1, $s_lab2, $s_lab3, $row1);
ok(ref $s_lab5, "Triceps::Label");

$s_op4 = $s_lab4->makeRowop(&Triceps::OP_NOP, $row1);
ok(ref $s_op4, "Triceps::Rowop");
$s_op5 = $s_lab5->makeRowop(&Triceps::OP_NOP, $row1);
ok(ref $s_op5, "Triceps::Rowop");

$s_expect =
	"unit 'u1' before label 'lab4' op OP_NOP\n"
	. "unit 'u1' before label 'lab3' op OP_INSERT\n"
	. "unit 'u1' before label 'lab3' op OP_DELETE\n"
	. "unit 'u1' before label 'lab2' op OP_INSERT\n"
	. "unit 'u1' before label 'lab2' op OP_DELETE\n"

	. "unit 'u1' before label 'lab5' op OP_NOP\n"
	. "unit 'u1' before label 'lab3' op OP_INSERT\n"
	. "unit 'u1' before label 'lab3' op OP_DELETE\n"
	. "unit 'u1' before label 'lab2' op OP_INSERT\n"
	. "unit 'u1' before label 'lab2' op OP_DELETE\n"

	. "unit 'u1' before label 'lab1' op OP_INSERT\n"
	. "unit 'u1' before label 'lab1' op OP_DELETE\n"
	. "unit 'u1' before label 'lab1' op OP_INSERT\n"
	. "unit 'u1' before label 'lab1' op OP_DELETE\n"
	;

$s_expect_verbose =
	"unit 'u1' before label 'lab4' op OP_NOP\n"
	. "unit 'u1' before label 'lab3' op OP_INSERT\n"
	. "unit 'u1' drain label 'lab3' op OP_INSERT\n"
	. "unit 'u1' after label 'lab3' op OP_INSERT\n"
	. "unit 'u1' before label 'lab3' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab3' op OP_DELETE\n"
	. "unit 'u1' after label 'lab3' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab4' op OP_NOP\n"
	. "unit 'u1' before label 'lab2' op OP_INSERT\n"
	. "unit 'u1' drain label 'lab2' op OP_INSERT\n"
	. "unit 'u1' after label 'lab2' op OP_INSERT\n"
	. "unit 'u1' before label 'lab2' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab2' op OP_DELETE\n"
	. "unit 'u1' after label 'lab2' op OP_DELETE\n"
	. "unit 'u1' after label 'lab4' op OP_NOP\n"
	. "unit 'u1' before label 'lab5' op OP_NOP\n"
	. "unit 'u1' before label 'lab3' op OP_INSERT\n"
	. "unit 'u1' drain label 'lab3' op OP_INSERT\n"
	. "unit 'u1' after label 'lab3' op OP_INSERT\n"
	. "unit 'u1' before label 'lab3' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab3' op OP_DELETE\n"
	. "unit 'u1' after label 'lab3' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab5' op OP_NOP\n"
	. "unit 'u1' before label 'lab2' op OP_INSERT\n"
	. "unit 'u1' drain label 'lab2' op OP_INSERT\n"
	. "unit 'u1' after label 'lab2' op OP_INSERT\n"
	. "unit 'u1' before label 'lab2' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab2' op OP_DELETE\n"
	. "unit 'u1' after label 'lab2' op OP_DELETE\n"
	. "unit 'u1' after label 'lab5' op OP_NOP\n"
	. "unit 'u1' before label 'lab1' op OP_INSERT\n"
	. "unit 'u1' drain label 'lab1' op OP_INSERT\n"
	. "unit 'u1' after label 'lab1' op OP_INSERT\n"
	. "unit 'u1' before label 'lab1' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab1' op OP_DELETE\n"
	. "unit 'u1' after label 'lab1' op OP_DELETE\n"
	. "unit 'u1' before label 'lab1' op OP_INSERT\n"
	. "unit 'u1' drain label 'lab1' op OP_INSERT\n"
	. "unit 'u1' after label 'lab1' op OP_INSERT\n"
	. "unit 'u1' before label 'lab1' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab1' op OP_DELETE\n"
	. "unit 'u1' after label 'lab1' op OP_DELETE\n"
	;

# execute with scheduling of op4, op5

$u1->schedule($s_op4);
ok($! . "", "");
$u1->enqueue("EM_SCHEDULE", $s_op5);
ok($! . "", "");
ok(!$u1->empty());

$u1->drainFrame();
ok($u1->empty());

$v = $sntr->print();
ok($v, $s_expect);

# check the buffer cleaning of string tracer
$sntr->clearBuffer();
ok($! . "", "");
$v = $sntr->print();
ok($v, "");

### repeat the same with the verbose tracer and fork() instead of schedule()

$sntr = Triceps::UnitTracerStringName->new(verbose => 1);
$u1->setTracer($sntr);
ok($! . "", "");

$u1->fork($s_op4);
ok($! . "", "");
$u1->enqueue("EM_FORK", $s_op5);
ok($! . "", "");
ok(!$u1->empty());

$u1->drainFrame();
ok($u1->empty());

$v = $sntr->print();
ok($v, $s_expect_verbose);

### same again but with Perl tracer

sub tracerCb() # unit, label, fromLabel, rop, when, extra
{
	my ($unit, $label, $from, $rop, $when, @extra) = @_;
	my $msg;
	our $history;

	$msg = "unit '" . $unit->getName() . "' " . Triceps::tracerWhenHumanString($when) . " label '" . $label->getName() . "' ";
	if (defined $fromLabel) {
		$msg .= "(chain '" . $fromLabel->getName() . "') ";
	}
	$msg .= "op " . Triceps::opcodeString($rop->getOpcode()) . "\n";
	$history .= $msg;
}

undef $history;
$ptr = Triceps::UnitTracerPerl->new(\&tracerCb);
$u1->setTracer($ptr);
ok($! . "", "");

$u1->fork($s_op4);
ok($! . "", "");
$u1->enqueue("EM_FORK", $s_op5);
ok($! . "", "");
ok(!$u1->empty());

$u1->drainFrame();
ok($u1->empty());

ok($history, $s_expect_verbose);

#############################################################
# test the chaining - as in t_Unit.cpp scheduling()

$sntr = Triceps::UnitTracerStringName->new(verbose => 1);
$u1->setTracer($sntr);
ok($! . "", "");

$c_lab1 = $u1->makeDummyLabel($rt1, "lab1");
ok(ref $c_lab1, "Triceps::Label");
$c_lab2 = $u1->makeDummyLabel($rt1, "lab2");
ok(ref $c_lab2, "Triceps::Label");
$c_lab3 = $u1->makeDummyLabel($rt1, "lab3");
ok(ref $c_lab3, "Triceps::Label");

$c_op1 = $c_lab1->makeRowop(&Triceps::OP_INSERT, $row1);
ok(ref $c_op1, "Triceps::Rowop");
$c_op2 = $c_lab1->makeRowop(&Triceps::OP_DELETE, $row1);
ok(ref $c_op2, "Triceps::Rowop");

$v = $c_lab1->chain($c_lab2);
ok($v);
$v = $c_lab1->chain($c_lab3);
ok($v);
$v = $c_lab2->chain($c_lab3);
ok($v);

$u1->schedule($c_op1);
$u1->schedule($c_op2);
ok(!$u1->empty());

$u1->drainFrame();
ok($u1->empty());

$c_expect =
	"unit 'u1' before label 'lab1' op OP_INSERT\n"
	. "unit 'u1' drain label 'lab1' op OP_INSERT\n"
	. "unit 'u1' before-chained label 'lab1' op OP_INSERT\n"
		. "unit 'u1' before label 'lab2' (chain 'lab1') op OP_INSERT\n"
		. "unit 'u1' drain label 'lab2' (chain 'lab1') op OP_INSERT\n"
		. "unit 'u1' before-chained label 'lab2' (chain 'lab1') op OP_INSERT\n"
			. "unit 'u1' before label 'lab3' (chain 'lab2') op OP_INSERT\n"
			. "unit 'u1' drain label 'lab3' (chain 'lab2') op OP_INSERT\n"
			. "unit 'u1' after label 'lab3' (chain 'lab2') op OP_INSERT\n"
		. "unit 'u1' after label 'lab2' (chain 'lab1') op OP_INSERT\n"

		. "unit 'u1' before label 'lab3' (chain 'lab1') op OP_INSERT\n"
		. "unit 'u1' drain label 'lab3' (chain 'lab1') op OP_INSERT\n"
		. "unit 'u1' after label 'lab3' (chain 'lab1') op OP_INSERT\n"
	. "unit 'u1' after label 'lab1' op OP_INSERT\n"

	. "unit 'u1' before label 'lab1' op OP_DELETE\n"
	. "unit 'u1' drain label 'lab1' op OP_DELETE\n"
	. "unit 'u1' before-chained label 'lab1' op OP_DELETE\n"
		. "unit 'u1' before label 'lab2' (chain 'lab1') op OP_DELETE\n"
		. "unit 'u1' drain label 'lab2' (chain 'lab1') op OP_DELETE\n"
		. "unit 'u1' before-chained label 'lab2' (chain 'lab1') op OP_DELETE\n"
			. "unit 'u1' before label 'lab3' (chain 'lab2') op OP_DELETE\n"
			. "unit 'u1' drain label 'lab3' (chain 'lab2') op OP_DELETE\n"
			. "unit 'u1' after label 'lab3' (chain 'lab2') op OP_DELETE\n"
		. "unit 'u1' after label 'lab2' (chain 'lab1') op OP_DELETE\n"

		. "unit 'u1' before label 'lab3' (chain 'lab1') op OP_DELETE\n"
		. "unit 'u1' drain label 'lab3' (chain 'lab1') op OP_DELETE\n"
		. "unit 'u1' after label 'lab3' (chain 'lab1') op OP_DELETE\n"
	. "unit 'u1' after label 'lab1' op OP_DELETE\n"
	;

$v = $sntr->print();
ok($v, $c_expect);

#############################################################
# frame marks are tested in FrameMark.t

#############################################################
# MUST BE LAST
# test the unit clearing

# direct
undef $clearlog;
$v = $xlab2->getUnit();
ok($u1->same($v));
$u1->clearLabels();
ok($clearlog, "clear xlab2 args=[a,b]\n");
$v = $xlab2->getUnit();
ok(!defined $v);
ok("$!", "Triceps::Label::getUnit: label has been already cleared");

# with a trigger object
$u2lab1 = $u2->makeDummyLabel($rt1, "u2lab1");
ok(ref $u2lab1, "Triceps::Label");
{
	my $trig = $u2->makeClearingTrigger();
	# check that the label is still alive
	$v = $u2lab1->getUnit();
	ok($u2->same($v));
}
# now the label on u2 should be cleared
$v = $u2lab1->getUnit();
ok(!defined $v);
ok("$!", "Triceps::Label::getUnit: label has been already cleared");
