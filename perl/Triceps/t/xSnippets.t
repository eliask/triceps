#
# (C) Copyright 2011-2012 Sergey A. Babkin.
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
BEGIN { plan tests => 5 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################

# row types equivalence

{
my $unit = Triceps::Unit->new("unit") or die "$!";

my @schema = (
	a => "int32",
	b => "string"
);

my $rt1 = Triceps::RowType->new(@schema) or die "$!";
# $rt2 is equal to $rt1: same field names and field types
my $rt2 = Triceps::RowType->new(@schema) or die "$!"; 
# $rt3  matches $rt1 and $rt2: same field types but different names
my $rt3 = Triceps::RowType->new(
	A => "int32",
	B => "string"
) or die "$!";

my $lab = $unit->makeDummyLabel($rt1, "lab") or die "$!";
# same type, efficient
my $rop1 = $lab->makeRowop(&Triceps::OP_INSERT,
	$rt1->makeRowArray(1, "x")) or die "$!";
# different row type, involves a comparison overhead
my $rop2 = $lab->makeRowop(&Triceps::OP_INSERT,
	$rt2->makeRowArray(1, "x")) or die "$!";
# different row type, involves a comparison overhead
my $rop3 = $lab->makeRowop(&Triceps::OP_INSERT,
	$rt3->makeRowArray(1, "x")) or die "$!";

ok($rop1);
ok($rop2);
ok($rop3);
}

#########################
# diamond calls

{
use strict;

my $result;

my $unit = Triceps::Unit->new("unit") or die "$!";

my $rtA = Triceps::RowType->new(
	key => "string",
	value => "int32",
) or die "$!";
my $rtD = Triceps::RowType->new(
	$rtA->getdef(),
	negative => "int32",
) or die "$!";

my ($lbA, $lbB, $lbC, $lbD);
$lbA = $unit->makeLabel($rtA, "A", undef, sub {
	my $rop = $_[1]; 
	my $op = $rop->getOpcode(); my $a = $rop->getRow();
	if ($a->get("value") < 0) {
		$unit->call($lbB->makeRowop($op, $a));
	} else {
		$unit->call($lbC->makeRowop($op, $a));
	}
}) or die "$!";

$lbB = $unit->makeLabel($rtA, "B", undef, sub {
	my $rop = $_[1]; 
	my $op = $rop->getOpcode(); my $a = $rop->getRow();
	$unit->makeHashCall($lbD, $op, $a->toHash(), negative => 1)
		or die "$!";
}) or die "$!";

$lbC = $unit->makeLabel($rtA, "C", undef, sub {
	my $rop = $_[1]; 
	my $op = $rop->getOpcode(); my $a = $rop->getRow();
	$unit->makeHashCall($lbD, $op, $a->toHash(), negative => 0)
		or die "$!";
}) or die "$!";

$lbD = $unit->makeLabel($rtD, "D", undef, sub {
	$result .= $_[1]->printP();
	$result .= "\n";
}) or die "$!";

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

