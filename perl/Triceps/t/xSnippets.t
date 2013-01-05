#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Code snippets from the docs, making sure that they work

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 14 };
use Triceps;
use Carp;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################

# row types equivalence

{
my $unit = Triceps::Unit->new("unit") or confess "$!";

my @schema = (
	a => "int32",
	b => "string"
);

my $rt1 = Triceps::RowType->new(@schema) or confess "$!";
# $rt2 is equal to $rt1: same field names and field types
my $rt2 = Triceps::RowType->new(@schema) or confess "$!"; 
# $rt3  matches $rt1 and $rt2: same field types but different names
my $rt3 = Triceps::RowType->new(
	A => "int32",
	B => "string"
) or confess "$!";

my $lab = $unit->makeDummyLabel($rt1, "lab") or confess "$!";
# same type, efficient
my $rop1 = $lab->makeRowop(&Triceps::OP_INSERT,
	$rt1->makeRowArray(1, "x")) or confess "$!";
# different row type, involves a comparison overhead
my $rop2 = $lab->makeRowop(&Triceps::OP_INSERT,
	$rt2->makeRowArray(1, "x")) or confess "$!";
# different row type, involves a comparison overhead
my $rop3 = $lab->makeRowop(&Triceps::OP_INSERT,
	$rt3->makeRowArray(1, "x")) or confess "$!";

ok($rop1);
ok($rop2);
ok($rop3);
}

#########################
# diamond calls

{
use strict;

my $result;

my $unit = Triceps::Unit->new("unit") or confess "$!";

my $rtA = Triceps::RowType->new(
	key => "string",
	value => "int32",
) or confess "$!";
my $rtD = Triceps::RowType->new(
	$rtA->getdef(),
	negative => "int32",
) or confess "$!";

my ($lbA, $lbB, $lbC, $lbD);
$lbA = $unit->makeLabel($rtA, "A", undef, sub {
	my $rop = $_[1]; 
	my $op = $rop->getOpcode(); my $a = $rop->getRow();
	if ($a->get("value") < 0) {
		$unit->call($lbB->makeRowop($op, $a));
	} else {
		$unit->call($lbC->makeRowop($op, $a));
	}
}) or confess "$!";

$lbB = $unit->makeLabel($rtA, "B", undef, sub {
	my $rop = $_[1]; 
	my $op = $rop->getOpcode(); my $a = $rop->getRow();
	$unit->makeHashCall($lbD, $op, $a->toHash(), negative => 1);
}) or confess "$!";

$lbC = $unit->makeLabel($rtA, "C", undef, sub {
	my $rop = $_[1]; 
	my $op = $rop->getOpcode(); my $a = $rop->getRow();
	$unit->makeHashCall($lbD, $op, $a->toHash(), negative => 0);
}) or confess "$!";

$lbD = $unit->makeLabel($rtD, "D", undef, sub {
	$result .= $_[1]->printP();
	$result .= "\n";
}) or confess "$!";

# the test
$unit->makeHashCall($lbA, "OP_INSERT", key => "key1", value => 10);
$unit->makeHashCall($lbA, "OP_DELETE", key => "key1", value => 10);
$unit->makeHashCall($lbA, "OP_INSERT", key => "key1", value => -1);
#print $result;
ok($result,
'D OP_INSERT key="key1" value="10" negative="0" 
D OP_DELETE key="key1" value="10" negative="0" 
D OP_INSERT key="key1" value="-1" negative="1" 
');

}

#########################
# Filtering of rows by adoption.

{
use strict;

my $result;

my $unit = Triceps::Unit->new("unit") or confess "$!";

my @schema = (
	a => "int32",
	b => "string"
);

my $rt1 = Triceps::RowType->new(@schema) or confess "$!";

my $lab2;

my $lab1 = $unit->makeLabel($rt1, "lab1", undef, sub {
	my ($label, $rowop) = @_;
	if ($rowop->getRow()->get("a") > 10) {
		$unit->call($lab2->adopt($rowop));
	}
}) or confess "$!";

$lab2 = $unit->makeLabel($rt1, "lab2", undef, sub {
	$result .= $_[1]->printP();
	$result .= "\n";
}) or confess "$!";

# the test
$unit->makeHashCall($lab1, "OP_INSERT", a => 20, b => "xxx");
$unit->makeHashCall($lab1, "OP_DELETE", a => 1, b => "yyy");
#print $result;
ok($result,
'lab2 OP_INSERT a="20" b="xxx" 
');

undef $lab2;
}

#########################
# Fibonacci stuff.

{
use strict;

sub fib1 # ($n)
{
	my $n = shift;
	if ($n <= 2) {
		return 1;
	} else {
		return &fib1($n-1) + &fib1($n-2);
	}
}
ok(&fib1(1), 1);
ok(&fib1(2), 1);
ok(&fib1(3), 2);
ok(&fib1(5), 5);

sub fibStep2 # ($prev, $preprev)
{
	return ($_[0] + $_[1], $_[0]);
}

sub fib2 # ($n)
{
	my $n = shift;
	my @prev = (1, 0); # n and n-1

	while ($n > 1) {
		@prev = &fibStep2(@prev);
		$n--;
	}
	return $prev[0];
}
ok(&fib2(1), 1);
ok(&fib2(2), 1);
ok(&fib2(3), 2);
ok(&fib2(5), 5);

}

