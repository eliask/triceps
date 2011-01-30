# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 37 };
use Biceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

@def1 = (
	a => "uint8",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
$rt1 = Biceps::RowType->new( # used later
	@def1
);
ok(ref $rt1, "Biceps::RowType");

@def3 = (
	a => "uint8[]",
	b => "int32[]",
	c => "int64[]",
	d => "float64[]",
	e => "string",
);
$rt3 = Biceps::RowType->new( # used later
	@def3
);
ok(ref $rt3, "Biceps::RowType");

#################### creating from hashes ######################

$r1 = $rt1->makerow_hs(
	a => "uint8",
	b => 123,
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(ref $r1, "Biceps::Row");
#print STDERR "\n$!\n";

# try an actual hash
%data1 = (
	a => "uint8",
	b => 123,
	c => 3e15,
	d => 3.14,
	e => "string",
);
$r1 = $rt1->makerow_hs(%data1);
ok(ref $r1, "Biceps::Row");

# try giving a non-numeric but convertible value to a numeric field
$r1 = $rt1->makerow_hs(
	a => "uint8",
	b => "123",
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(ref $r1, "Biceps::Row");

# try giving a non-numeric and non-convertible value to a numeric field
print STDERR "Ignore the following message about non-numeric, if any\n";
$r1 = $rt1->makerow_hs(
	a => "uint8",
	b => "z123",
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(ref $r1, "Biceps::Row");

# test that scalar can be transparently set to arrays
$r1 = $rt3->makerow_hs(
	a => "uint8",
	b => 123,
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(ref $r1, "Biceps::Row");

$r1 = $rt1->makerow_hs(
	a => undef,
	b => 123,
	c => 3e15,
	e => "string",
);
ok(ref $r1, "Biceps::Row");

# all-null row
$r1 = $rt1->makerow_hs();
ok(ref $r1, "Biceps::Row");

# try all the errors
$r1 = $rt1->makerow_hs(
	a => "uint8",
	b => [ 0x123, 0x456 ],
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(!defined $r1);
ok($! . "", "Biceps::RowType::makerow_hs: attempting to set an array into scalar field 'b'");

$r1 = $rt1->makerow_hs(
	z => "uint8",
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(!defined $r1);
ok($! . "", "Biceps::RowType::makerow_hs: attempting to set an unknown field 'z'");

$r1 = $rt1->makerow_hs(
	a => undef,
	b => 123,
	c => 3e15,
	"e"
);
ok(!defined $r1);
ok($! . "", "Usage: Biceps::RowType::makerow_hs(RowType, fieldName, fieldValue, ...), names and types must go in pairs");

# array fields
$r1 = $rt3->makerow_hs(
	a => "uint8",
	b => [ 0x123, 0x456 ],
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(ref $r1, "Biceps::Row");
#print STDERR "\n", $r1->hexdump;

$r1 = $rt3->makerow_hs(
	a => [ "uint8" ],
	b => [ 0x123, 0x456 ],
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(!defined $r1);
ok($! . "", "Biceps field 'a' data conversion: array reference may not be used for string and uint8");

# errors related to array fields
$r1 = $rt3->makerow_hs(
	a => "uint8",
	b => [ 0x123, 0x456 ],
	c => 3e15,
	d => 3.14,
	e => [ "string" ],
);
ok(!defined $r1);
ok($! . "", "Biceps::RowType::makerow_hs: attempting to set an array into scalar field 'e'");

$r1 = $rt3->makerow_hs(
	a => "uint8",
	b => { "a" , 0x456 },
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(!defined $r1);
ok($! . "", "Biceps field 'b' data conversion: reference not to an array");

#################### creating from CSV-style arrays ######################

$r1 = $rt1->makerow_ar(
	"uint8",
	123,
	3e15,
	3.14,
	"string",
);
ok(ref $r1, "Biceps::Row");

# test that scalar can be transparently set to arrays
$r1 = $rt3->makerow_ar(
	"uint8",
	123,
	3e15,
	3.14,
	"string",
);
ok(ref $r1, "Biceps::Row");

# all-null row
$r1 = $rt1->makerow_ar();
ok(ref $r1, "Biceps::Row");

# try all the errors
$r1 = $rt1->makerow_ar(
	"uint8",
	[ 0x123, 0x456 ],
	3e15,
	3.14,
	"string",
);
ok(!defined $r1);
ok($! . "", "Biceps::RowType::makerow_ar: attempting to set an array into scalar field 'b'");

$r1 = $rt1->makerow_ar(
	a => undef,
	b => 123,
	c => 3e15,
	"e"
);
ok(!defined $r1);
ok($! . "", "Biceps::RowType::makerow_ar: 7 args, only 5 fields in row { uint8 a, int32 b, int64 c, float64 d, string e, }");

# array fields
$r1 = $rt3->makerow_ar(
	"uint8",
	[ 0x123, 0x456 ],
	3e15,
	3.14,
	"string",
);
ok(ref $r1, "Biceps::Row");
#print STDERR "\n", $r1->hexdump;

$r1 = $rt3->makerow_ar(
	[ "uint8" ],
	[ 0x123, 0x456 ],
	3e15,
	3.14,
	"string",
);
ok(!defined $r1);
ok($! . "", "Biceps field 'a' data conversion: array reference may not be used for string and uint8");

# errors related to array fields
$r1 = $rt3->makerow_ar(
	"uint8",
	[ 0x123, 0x456 ],
	3e15,
	3.14,
	[ "string" ],
);
ok(!defined $r1);
ok($! . "", "Biceps::RowType::makerow_ar: attempting to set an array into scalar field 'e'");

$r1 = $rt3->makerow_ar(
	"uint8",
	{ "a" , 0x456 },
	3e15,
	3.14,
	"string",
);
ok(!defined $r1);
ok($! . "", "Biceps field 'b' data conversion: reference not to an array");

