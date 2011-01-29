# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 15 };
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
@xdef1 = $rt1->getdef();
ok(join(",", @xdef1), join(",", @def1));

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
@xdef3 = $rt3->getdef();
ok(join(",", @xdef3), join(",", @def3));

$rt2 = Biceps::RowType->new(
	a => "void",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string[]",
);
ok(!defined $rt2);
ok($! . "", "Biceps::RowType::new: field 'e' string array type is not supported");

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

