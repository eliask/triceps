# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 13 };
use Biceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

$rt1 = Biceps::RowType->new(
	a => "uint8",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
ok(ref $rt1, "Biceps::RowType");

$rt2 = Biceps::RowType->new(
	a => "void",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
ok(!defined $rt2);
ok($! . "", "Biceps::RowType::new: field 'a' type must not be void");

$rt2 = Biceps::RowType->new(
	a => "",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
ok(!defined $rt2);
ok($! . "", "Biceps::RowType::new: field 'a' has an unknown type ''");

$rt2 = Biceps::RowType->new(
);
ok(!defined $rt2);
ok($! . "", "Usage: Biceps::RowType::new(CLASS, fieldName, fieldType, ...), names and types must go in pairs");

undef $!;
$rt2 = Biceps::RowType->new(
	a => "",
	b => "int32",
	c => "int64",
	d => "float64",
	"string",
);
ok(!defined $rt2);
ok($! . "", "Usage: Biceps::RowType::new(CLASS, fieldName, fieldType, ...), names and types must go in pairs");

$r1 = $rt1->makerow(
	a => "uint8",
	b => 123,
	c => 3e15,
	d => 3.14,
	e => "string",
);
ok(ref $r1, "Biceps::Row");

$r1 = $rt1->makerow(
	a => undef,
	b => 123,
	c => 3e15,
	e => "string",
);
ok(ref $r1, "Biceps::Row");

$r1 = $rt1->makerow(
	a => "uint8",
	b => [ 123, 456 ],
	c => 3e15,
	d => 3.14,
	e => "string",
);
#ok(ref $r1, "Biceps::Row");
ok(!defined $r1);

