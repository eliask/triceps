# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 19 };
use Biceps;
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

########################### hash format ################################

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

# non-null scalars
@dataset1 = (
	a => "uint8",
	b => 123,
	c => 3e15+0,
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

# nulls
@dataset2 = (
	a => undef,
	b => undef,
	c => 3e15+0,
	d => undef,
	e => undef,
);
$r2 = $rt1->makerow_hs( @dataset2);
ok(ref $r2, "Biceps::Row");

@d2 = $r2->to_hs();
ok(join(',', map {defined $_? $_ : "-"} @d2), join(',', map {defined $_? $_ : "-"} @dataset2));
#print STDERR "\n dataset d2: ", &row2string(@d2), "\n";

# vectors
@dataset3 = (
	a => "uint8",
	b => [ 123, 456, 789 ],
	c => [ 3e15+0, 42, 65535 ], # +0 triggers the data conversion to int64 in Perl
	d => [ 3.14, 2.71, 3.123456789012345+0 ],
	e => "string",
);
#print STDERR "\n dataset:", &row2string(@dataset3), "\n";
$r3 = $rt3->makerow_hs( @dataset3);
ok(ref $r3, "Biceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
#print STDERR "\n", $r3->hexdump;

@d3 = $r3->to_hs();
ok(&row2string(@d3), &row2string(@dataset3));

# vectors with nulls
@dataset4 = (
	a => "uint8",
	b => undef,
	c => undef,
	d => undef,
	e => "string",
);
#print STDERR "\n dataset:", &row2string(@dataset4), "\n";
$r4 = $rt3->makerow_hs( @dataset4);
ok(ref $r4, "Biceps::Row");

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
ok(ref $r1, "Biceps::Row");

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
ok(ref $r2, "Biceps::Row");

@d2 = $r2->to_ar();
ok(&row2string(@d2), &row2string(undef,undef,3e15+0,undef,undef));
#print STDERR "\n dataset d2: ", &row2string(@d2), "\n";

# vectors
@dataset3 = (
	"uint8",
	[ 123, 456, 789 ],
	[ 3e15+0, 42, 65535 ], # +0 triggers the data conversion to int64 in Perl
	[ 3.14, 2.71, 3.123456789012345+0 ],
	"string",
);
#print STDERR "\n dataset:", &row2string(@dataset3), "\n";
$r3 = $rt3->makerow_ar( @dataset3);
ok(ref $r3, "Biceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
#print STDERR "\n", $r3->hexdump;

@d3 = $r3->to_ar();
ok(&row2string(@d3), &row2string(@dataset3));

# vectors with nulls
@dataset4 = (
	"uint8",
	undef,
	undef,
	undef,
	"string",
);
#print STDERR "\n dataset:", &row2string(@dataset4), "\n";
$r4 = $rt3->makerow_ar( @dataset4);
ok(ref $r4, "Biceps::Row");

# this result is dependent on the machine byte order, so it's not for final tests
# but just for debugging
#print STDERR "\n", $r4->hexdump;

@d4 = $r4->to_ar();
ok(&row2string(@d4), &row2string(@dataset4));

