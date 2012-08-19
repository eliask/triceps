#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for streaming functions: FnReturn, FnBinding etc.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 51 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


######################### preparations (originating from Table.t)  #############################

my $u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

my $u2 = Triceps::Unit->new("u2");
ok(ref $u2, "Triceps::Unit");

my @def1 = (
	a => "uint8",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
my $rt1 = Triceps::RowType->new( # used later
	@def1
);
ok(ref $rt1, "Triceps::RowType");

my $rt2 = Triceps::RowType->new( # used later
	@def1,
	f => "int32",
);
ok(ref $rt2, "Triceps::RowType");

my $lb1 = $u1->makeDummyLabel($rt1, "lb1");
ok(ref $lb1, "Triceps::Label");
my $lb2 = $u1->makeDummyLabel($rt2, "lb2");
ok(ref $lb2, "Triceps::Label");

my $lb1x = $u2->makeDummyLabel($rt1, "lb1x");
ok(ref $lb1x, "Triceps::Label");

######################### 
# FnReturn

# with explict unit
my $fret1 = Triceps::FnReturn->new(
	name => "fret1",
	unit => $u1,
	labels => [
		one => $lb1,
		two => $rt2,
	]
);
ok(ref $fret1, "Triceps::FnReturn");

# without explict unit, two labels
my $fret2 = Triceps::FnReturn->new(
	name => "fret2",
	labels => [
		one => $lb1,
		two => $lb2,
	]
);
ok(ref $fret2, "Triceps::FnReturn");

# sameness
ok($fret1->same($fret1));
ok(!$fret1->same($fret2));

######################### 
# FnReturn construction errors

sub badFnReturn # (optName, optValue, ...)
{
	my %opt = (
		name => "fret1",
		labels => [
			one => $lb1,
			two => $rt2,
		]
	);
	while ($#_ >= 1) {
		if (defined $_[1]) {
			$opt{$_[0]} = $_[1];
		} else {
			delete $opt{$_[0]};
		}
		shift; shift;
	}
	my $res = eval {
		Triceps::FnReturn->new(%opt);
	};
	ok(!defined $res);
}

{
	# do this one manually, since badFnReturn can't handle unpaired args
	my $res = eval {
		my $fret2 = Triceps::FnReturn->new(
			name => "fret1",
			[
				one => $lb1,
				two => $rt2,
			]
		);
	};
	ok(!defined $res);
	ok($@ =~ /^Usage: Triceps::FnReturn::new\(CLASS, optionName, optionValue, ...\), option names and values must go in pairs/);
	#print "$@"
}

&badFnReturn(xxx => "fret1");
ok($@ =~ /^Triceps::FnReturn::new: unknown option 'xxx'/);

&badFnReturn(name => 1);
ok($@ =~ /^Triceps::FnReturn::new: option 'name' value must be a string/);

&badFnReturn(unit => "u1");
ok($@ =~ /^Triceps::FnReturn::new: option 'unit' value must be a blessed SV reference to Triceps::Unit/);

&badFnReturn(unit => $rt1);
ok($@ =~ /^Triceps::FnReturn::new: option 'unit' value has an incorrect magic for Triceps::Unit/);

&badFnReturn(
	labels => {
		one => $lb1,
		two => $rt2,
	}
);
ok($@ =~ /^Triceps::FnReturn::new: option 'labels' value must be a reference to array/);

&badFnReturn(labels => undef);
ok($@ =~ /^Triceps::FnReturn::new: missing mandatory option 'labels'/);

&badFnReturn(
	labels => [
		one => $lb1,
		"two"
	]
);
ok($@ =~ /^Triceps::FnReturn::new: option 'labels' must contain elements in pairs, has 3 elements/);

&badFnReturn(
	labels => [
		one => $lb1,
		$lb2 => "two",
	]
);
ok($@ =~ /^Triceps::FnReturn::new: in option 'labels' element 2 name must be a string/);

&badFnReturn(
	labels => [
		one => $lb1,
		two => 1,
	]
);
ok($@ =~ /^Triceps::FnReturn::new: in option 'labels' element 2 with name 'two' value must be a blessed SV reference to Triceps::Label or Triceps::RowType/);

{
	my $lbc = $u1->makeDummyLabel($rt1, "lbc");
	ok(ref $lbc, "Triceps::Label");
	$lbc->clear();
	&badFnReturn(
		labels => [
			one => $lb1,
			two => $lbc,
		]
	);
}
ok($@ =~ /^Triceps::FnReturn::new: a cleared label in option 'labels' element 2 with name 'two' can not be used/);

&badFnReturn(
	labels => [
		one => $lb1x,
		two => $lb2,
	]
);
ok($@ =~ /^Triceps::FnReturn::new: label in option 'labels' element 2 with name 'two' has a mismatching unit 'u1', previously seen unit 'u2'/);

&badFnReturn(
	labels => [
		one => $rt1,
		two => $rt2,
	]
);
ok($@ =~ /^Triceps::FnReturn::new: the unit can not be auto-deduced, must use an explicit option 'unit'/);

&badFnReturn(name => "");
ok($@ =~ /^Triceps::FnReturn::new: must specify a non-empty name with option 'name'/);

&badFnReturn(labels => [ one => $u1, two => $lb2, ]);
ok($@ =~ /^Triceps::FnReturn::new: in option 'labels' element 1 with name 'one' value has an incorrect magic for either Triceps::Label or Triceps::RowType/);

&badFnReturn(
	labels => [
		one => $lb1,
		one => $lb2,
	]
);
# XXX should have a better way to prepend the high-level description
ok($@ =~ /^Triceps::FnReturn::new: invalid arguments:\n  duplicate row name 'one'/);
#print "$@";

######################### 
# FnBinding

my $lbind1 = $u2->makeDummyLabel($rt1, "lbind1");
ok(ref $lbind1, "Triceps::Label");
my $lbind2 = $u2->makeDummyLabel($rt2, "lbind2");
ok(ref $lbind2, "Triceps::Label");

# with labels only, no name, no unit
my $fbind1 = Triceps::FnBinding->new(
	on => $fret1,
	labels => [
		one => $lbind1,
		two => $lbind2,
	]
);
ok(ref $fbind1, "Triceps::FnBinding");

# with labels made from code snippets
my $fbind2 = Triceps::FnBinding->new(
	on => $fret1,
	name => "fbind2",
	unit => $u2,
	labels => [
		one => $lb1,
		two => $lb2,
	]
);
ok(ref $fbind2, "Triceps::FnBinding");

# sameness
ok($fbind1->same($fbind1));
ok(!$fbind1->same($fbind2));

