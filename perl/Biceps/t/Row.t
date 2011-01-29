# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 5 };
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

@dataset1 = (
	a => "uint8",
	b => 123,
	c => 3e15,
	d => 3.14,
	e => "string",
);
$r1 = $rt1->makerow_hs( @dataset1);
ok(ref $r1, "Biceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
# print STDERR "\n", $r1->hexdump;

@d1 = $r1->to_hs();
ok(join(',', @d1), join(',', @dataset1));
