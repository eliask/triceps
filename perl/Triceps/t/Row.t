#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for Row.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 70 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

sub row2string 
{
	join (', ', map {
		if (defined $_) {
			if (ref $_) {
				'[' . join(', ', @$_) . ']'
			} else {
				$_
			}
		} else {
			'-'
		}
	} @_);
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

########################### types for later use ################################

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

@def3 = (
	a => "uint8[]",
	b => "int32[]",
	c => "int64[]",
	d => "float64[]",
	e => "string",
);
$rt3 = Triceps::RowType->new( # used later
	@def3
);
ok(ref $rt3, "Triceps::RowType");

########################### hash format ################################

# non-null scalars
@dataset1 = (
	a => "uint8",
	b => 123,
	c => 3e15+0,
	d => 3.14,
	e => "string",
);
$r1 = $rt1->makerow_hs( @dataset1);
ok(ref $r1, "Triceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
# print STDERR "\n", $r1->hexdump;

@d1 = $r1->to_hs();
ok(join(',', @d1), join(',', @dataset1));

# nulls
@dataset2 = (
	a => undef,
	b => undef,
	c => 3e15+0,
	d => undef,
	e => undef,
);
$r2 = $rt1->makerow_hs( @dataset2);
ok(ref $r2, "Triceps::Row");

@d2 = $r2->to_hs();
ok(join(',', map {defined $_? $_ : "-"} @d2), join(',', map {defined $_? $_ : "-"} @dataset2));
#print STDERR "\n dataset d2: ", &row2string(@d2), "\n";

# arrays
@dataset3 = (
	a => "uint8",
	b => [ 123, 456, 789 ],
	c => [ 3e15+0, 42, 65535 ], # +0 triggers the data conversion to int64 in Perl
	d => [ 3.14, 2.71, 3.123456789012345+0 ],
	e => "string",
);
#print STDERR "\n dataset:", &row2string(@dataset3), "\n";
$r3 = $rt3->makerow_hs( @dataset3);
ok(ref $r3, "Triceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
#print STDERR "\n", $r3->hexdump;

@d3 = $r3->to_hs();
ok(&row2string(@d3), &row2string(@dataset3));

# arrays with nulls
@dataset4 = (
	a => "uint8",
	b => undef,
	c => undef,
	d => undef,
	e => "string",
);
#print STDERR "\n dataset:", &row2string(@dataset4), "\n";
$r4 = $rt3->makerow_hs( @dataset4);
ok(ref $r4, "Triceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
#print STDERR "\n", $r4->hexdump;

@d4 = $r4->to_hs();
ok(&row2string(@d4), &row2string(@dataset4));

########################### array CSV-like format ################################

# non-null scalars
@dataset1 = (
	"uint8",
	123,
	3e15+0,
	3.14,
	"string",
);
$r1 = $rt1->makerow_ar( @dataset1);
ok(ref $r1, "Triceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
# print STDERR "\n", $r1->hexdump;

@d1 = $r1->to_ar();
ok(join(',', @d1), join(',', @dataset1));

# nulls and auto-filling
@dataset2 = (
	undef,
	undef,
	3e15+0,
);
$r2 = $rt1->makerow_ar( @dataset2);
ok(ref $r2, "Triceps::Row");

@d2 = $r2->to_ar();
ok(&row2string(@d2), &row2string(undef,undef,3e15+0,undef,undef));
#print STDERR "\n dataset d2: ", &row2string(@d2), "\n";

# arrays
@dataset3 = (
	"uint8",
	[ 123, 456, 789 ],
	[ 3e15+0, 42, 65535 ], # +0 triggers the data conversion to int64 in Perl
	[ 3.14, 2.71, 3.123456789012345+0 ],
	"string",
);
#print STDERR "\n dataset:", &row2string(@dataset3), "\n";
$r3 = $rt3->makerow_ar( @dataset3);
ok(ref $r3, "Triceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
#print STDERR "\n", $r3->hexdump;

@d3 = $r3->to_ar();
ok(&row2string(@d3), &row2string(@dataset3));

# arrays with nulls
@dataset4 = (
	"uint8",
	undef,
	undef,
	undef,
	"string",
);
#print STDERR "\n dataset:", &row2string(@dataset4), "\n";
$r4 = $rt3->makerow_ar( @dataset4);
ok(ref $r4, "Triceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
#print STDERR "\n", $r4->hexdump;

@d4 = $r4->to_ar();
ok(&row2string(@d4), &row2string(@dataset4));

########################### copymod ################################

# non-null scalars
@dataset1 = (
	a => "uint8",
	b => 123,
	c => 3e15+0,
	d => 3.14,
	e => "string",
);
$r1 = $rt1->makerow_hs( @dataset1);
ok(ref $r1, "Triceps::Row");

$r2 = $r1->copymod(
	b => 456,
	e => "changed",
);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(
	a => "uint8",
	b => 456,
	c => 3e15+0,
	d => 3.14,
	e => "changed",
));
# check that the original row didn't change
@d2 = $r1->to_hs();
ok(&row2string(@d2), &row2string(@dataset1));

# replacing all fields
@dataset2 = (
	a => "bytes",
	b => 789,
	c => 4e15+0,
	d => 2.71,
	e => "text",
);
$r2 = $r1->copymod(@dataset2);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(@dataset2));

# replacing non-nulls with nulls
@dataset3 = (
	a => undef,
	b => undef,
	c => undef,
	d => undef,
	e => undef,
);
$r2 = $r1->copymod(@dataset3);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(@dataset3));

# replacing nulls with non-nulls
$r2 = $r2->copymod(@dataset2);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(@dataset2));

# arrays 
# replacing some fields
@dataset1 = (
	a => "uint8",
	b => [ 123, 456, 789 ],
	c => [ 3e15+0, 42, 65535 ],
	d => [ 3.14, 2.71, 3.123456789012345+0 ],
	e => "string",
);
$r1 = $rt3->makerow_hs( @dataset1);
ok(ref $r1, "Triceps::Row");

@dataset3 = (
	a => "bytesbytes",
	b => [ 950, 888, 123, 456, 789 ],
	c => [ 3e15+0, 42, 65535 ],
	d => [ 3.14, 2.71, 3.123456789012345+0 ],
	e => "string",
);
$r2 = $r1->copymod(
	a => "bytesbytes",
	b => [ 950, 888, 123, 456, 789 ],
);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(@dataset3));
# check that the original row didn't change
@d2 = $r1->to_hs();
ok(&row2string(@d2), &row2string(@dataset1));

# replacing all fields, with scalars
@dataset2 = (
	a => "bytes",
	b => 789,
	c => 4e15+0,
	d => 2.71,
	e => "text",
);
$r2 = $r1->copymod(@dataset2);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(
	a => "bytes",
	b => [ 789, ],
	c => [ 4e15+0, ],
	d => [ 2.71, ],
	e => "text",
));

# replacing all fields with nulls
@dataset3 = (
	a => undef,
	b => undef,
	c => undef,
	d => undef,
	e => undef,
);
$r2 = $r1->copymod(@dataset3);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(@dataset3));

# replacing nulls with non-nulls
$r2 = $r2->copymod(@dataset3);
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(@dataset3));

# changing nothing
$r2 = $r1->copymod();
ok(ref $r2, "Triceps::Row");
@d2 = $r2->to_hs();
ok(&row2string(@d2), &row2string(@dataset1));

# wrong arg number
$r2 = $r1->copymod(
	a => undef,
	b => 123,
	c => 3e15,
	"e"
);
ok(!defined $r2);
ok($! . "", "Usage: Triceps::Row::copymod(RowType, [fieldName, fieldValue, ...]), names and types must go in pairs");

# unknown field
$r2 = $r1->copymod(
	z => 123,
);
ok(!defined $r2);
ok($! . "", "Triceps::Row::copymod: attempting to set an unknown field 'z'");

# setting an array to a scalar field
@dataset1 = (
	a => "uint8",
	b => 123,
	c => 3e15+0,
	d => 3.14,
	e => "string",
);
$r1 = $rt1->makerow_hs( @dataset1);
ok(ref $r1, "Triceps::Row");

$r2 = $r1->copymod(
	b => [ 950, 888, 123, 456, 789 ],
);
ok(!defined $r2);
ok($! . "", "Triceps::Row::copymod: attempting to set an array into scalar field 'b'");

# setting an array for uint8
$r1 = $rt3->makerow_hs( @dataset1);
ok(ref $r1, "Triceps::Row");

$r2 = $r1->copymod(
	a => [ "a", "b", "c" ],
);
ok(!defined $r2);
ok($! . "", "Triceps field 'a' data conversion: array reference may not be used for string and uint8");

############ get #################################

# get a scalar
@dataset1 = (
	a => "uint8",
	b => 123,
	c => 3e15+0,
	d => 3.14,
	e => "string",
);
$r1 = $rt1->makerow_hs( @dataset1);
ok(ref $r1, "Triceps::Row");

ok($r1->get("a"), "uint8");
ok($r1->get("b"), 123);
ok($r1->get("c"), 3e15+0);
ok($r1->get("d"), 3.14);
ok($r1->get("e"), "string");

# getting an unknown field
ok(!defined $r1->get("z"));
ok($! . "", "Triceps::Row::get: unknown field 'z'");

# getting a null field
@dataset2 = (
	a => undef,
	b => undef,
	c => 3e15+0,
	d => undef,
	e => undef,
);
$r2 = $rt1->makerow_hs( @dataset2);
ok(ref $r2, "Triceps::Row");

ok(!defined $r2->get("a"));
ok($! . "", "");

# getting array fields
@dataset3 = (
	a => "bytesbytes",
	b => [ 950, 888, 123, 456, 789 ],
	c => [ 3e15+0, 42, 65535 ],
	d => [ 3.14, 2.71, 3.123456789012345+0 ],
	e => "string",
);
$r1 = $rt3->makerow_hs( @dataset3);
ok(ref $r1, "Triceps::Row");

ok($r1->get("a"), "bytesbytes");
$v = $r1->get("b");
ok(&row2string(@$v), &row2string(@{$dataset3[3]}));
$v = $r1->get("c");
ok(&row2string(@$v), &row2string(@{$dataset3[5]}));
$v = $r1->get("d");
ok(&row2string(@$v), &row2string(@{$dataset3[7]}));

# getting null from an array field
@dataset2 = (
	a => undef,
	b => undef,
	c => 3e15+0,
	d => undef,
	e => undef,
);
$r2 = $rt3->makerow_hs( @dataset2);
ok(ref $r2, "Triceps::Row");

ok(!defined $r2->get("a"));
ok($! . "", "");

