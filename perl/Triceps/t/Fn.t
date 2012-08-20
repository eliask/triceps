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
BEGIN { plan tests => 106 };
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

# one of a different type
my $fret3 = Triceps::FnReturn->new(
	name => "fret3",
	labels => [
		one => $lb2, # labels flipped
		two => $lb1,
	]
);
ok(ref $fret3, "Triceps::FnReturn");

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

my @called;

# with labels made from code snippets
my $fbind2 = Triceps::FnBinding->new(
	on => $fret1,
	name => "fbind2",
	unit => $u2,
	labels => [
		one => sub { $called[0]++; },
		two => sub { $called[1]++; },
	]
);
ok(ref $fbind2, "Triceps::FnBinding");

# labels don't have to be set at all (but the option must be present)
my $fbind3 = Triceps::FnBinding->new(
	on => $fret2, # has the same row set as fret1
	labels => [
	]
);
ok(ref $fbind3, "Triceps::FnBinding");

# one for a different FnReturn type
my $fbind4 = Triceps::FnBinding->new(
	on => $fret3,
	labels => [
	]
);
ok(ref $fbind4, "Triceps::FnBinding");

# sameness
ok($fbind1->same($fbind1));
ok(!$fbind1->same($fbind2));

######################### 
# FnBinding construction errors

sub badFnBinding # (optName, optValue, ...)
{
	my %opt = (
		name => "fbindx",
		unit => $u2,
		on => $fret1,
		labels => [
			one => $lbind1,
			two => sub { $called[1]++; },
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
		Triceps::FnBinding->new(%opt);
	};
	ok(!defined $res);
}

{
	# do this one manually, since badFnBinding can't handle unpaired args
	my $res = eval {
		my $fbind2 = Triceps::FnBinding->new(
			name => "fbindx",
			[
				one => $lbind1,
				two => sub { $called[1]++; },
			]
		);
	};
	ok(!defined $res);
	ok($@ =~ /^Usage: Triceps::FnBinding::new\(CLASS, optionName, optionValue, ...\), option names and values must go in pairs/);
	#print "$@"
}

&badFnBinding(xxx => "fbind1");
ok($@ =~ /^Triceps::FnBinding::new: unknown option 'xxx'/);

&badFnBinding(on => undef);
ok($@ =~ /^Triceps::FnBinding::new: missing mandatory option 'on'/);

&badFnBinding(labels => undef);
ok($@ =~ /^Triceps::FnBinding::new: missing mandatory option 'labels'/);

&badFnBinding(unit => 'x');
ok($@ =~ /^Triceps::FnBinding::new: option 'unit' value must be a blessed SV reference to Triceps::Unit/);

&badFnBinding(on => $u1);
ok($@ =~ /^Triceps::FnBinding::new: option 'on' value has an incorrect magic for Triceps::FnReturn/);

&badFnBinding(labels => {});
ok($@ =~ /^Triceps::FnBinding::new: option 'labels' value must be a reference to array/);

&badFnBinding(name => {});
ok($@ =~ /^Triceps::FnBinding::new: option 'name' value must be a string/);

&badFnBinding(labels => [ "x" ]);
ok($@ =~ /^Triceps::FnBinding::new: option 'labels' must contain elements in pairs, has 1 elements/);

&badFnBinding(labels => [ $fret1 => $lbind1, ]);
ok($@ =~ /^Triceps::FnBinding::new: in option 'labels' element 1 name value must be a string/);

&badFnBinding(labels => [ one => "zzz", ]);
ok($@ =~ /^Triceps::FnBinding::new: in option 'labels' element 1 with name 'one' value must be a reference to Triceps::Label or a function/);

&badFnBinding(name => undef);
ok($@ =~ /^Triceps::FnBinding::new: option 'name' must be set to handle the code reference in option 'labels' element 2 with name 'two'/);

&badFnBinding(unit => undef);
ok($@ =~ /^Triceps::FnBinding::new: option 'unit' must be set to handle the code reference in option 'labels' element 2 with name 'two'/);

&badFnBinding(labels => [ zzz => sub { }, ]);
ok($@ =~ /^Triceps::FnBinding::new: in option 'labels' element 1 has an unknown return label name 'zzz'/);

&badFnBinding(labels => [ zzz => $lbind1, ]);
ok($@ =~ /^Triceps::FnBinding::new: invalid arguments:\n  Unknown return label name 'zzz'/);

&badFnBinding(labels => [ two => $lbind1, ]);
ok($@ =~ /^Triceps::FnBinding::new: invalid arguments:
  Attempted to add a mismatching label 'lbind1' to name 'two'.
    The expected row type:
    row {
        uint8 a,
        int32 b,
        int64 c,
        float64 d,
        string e,
        int32 f,
      }
    The row type of actual label 'lbind1':
    row {
        uint8 a,
        int32 b,
        int64 c,
        float64 d,
        string e,
      }/);
#print "$@";

######################### 
# Run the code.

# create new labels and returns, to avoid the mess with all the labels
my $lbz1 = $u1->makeDummyLabel($rt1, "lbz1");
ok(ref $lbz1, "Triceps::Label");
my $lbz2 = $u1->makeDummyLabel($rt2, "lbz2");
ok(ref $lbz2, "Triceps::Label");

my $fretz1 = Triceps::FnReturn->new(
	name => "fretz1",
	unit => $u1,
	labels => [
		one => $lbz1,
		two => $lbz2,
	]
);
ok(ref $fretz1, "Triceps::FnReturn");

# a cross-unit binding
my $fbindz1 = Triceps::FnBinding->new(
	on => $fretz1,
	name => "fbindz1",
	unit => $u2,
	labels => [
		one => sub { $called[0]++; },
		two => sub { $called[1]++; },
	]
);
ok(ref $fbindz1, "Triceps::FnBinding");

# an empty binding
my $fbindz2 = Triceps::FnBinding->new(
	on => $fretz1,
	labels => [ ]
);
ok(ref $fbindz2, "Triceps::FnBinding");

my $ts1 = Triceps::UnitTracerStringName->new(verbose => 1);
$u1->setTracer($ts1);
my $ts2 = Triceps::UnitTracerStringName->new(verbose => 1);
$u2->setTracer($ts2);

my $rop1 = $lbz1->makeRowopHash("OP_INSERT");
ok(ref $rop1, "Triceps::Rowop");

# Run with no bindings.
{
	$u1->call($rop1);
	my $v1 = $ts1->print();
	ok($v1, 
"unit 'u1' before label 'lbz1' op OP_INSERT {
unit 'u1' drain label 'lbz1' op OP_INSERT
unit 'u1' before-chained label 'lbz1' op OP_INSERT
unit 'u1' before label 'fretz1.one' (chain 'lbz1') op OP_INSERT {
unit 'u1' drain label 'fretz1.one' (chain 'lbz1') op OP_INSERT
unit 'u1' after label 'fretz1.one' (chain 'lbz1') op OP_INSERT }
unit 'u1' after label 'lbz1' op OP_INSERT }
");
	#print "$v1";
	my $v2 = $ts2->print();
	ok($v2, "");
	$ts1->clearBuffer();
	$ts2->clearBuffer();
}

# Run with a binding pushed on.
{
	$fretz1->push($fbindz1);

	$u1->call($rop1);
	my $v1 = $ts1->print();
	ok($v1, 
"unit 'u1' before label 'lbz1' op OP_INSERT {
unit 'u1' drain label 'lbz1' op OP_INSERT
unit 'u1' before-chained label 'lbz1' op OP_INSERT
unit 'u1' before label 'fretz1.one' (chain 'lbz1') op OP_INSERT {
unit 'u1' drain label 'fretz1.one' (chain 'lbz1') op OP_INSERT
unit 'u1' after label 'fretz1.one' (chain 'lbz1') op OP_INSERT }
unit 'u1' after label 'lbz1' op OP_INSERT }
");
	my $v2 = $ts2->print();
	ok($v2, 
"unit 'u2' before label 'fbindz1.one' op OP_INSERT {
unit 'u2' drain label 'fbindz1.one' op OP_INSERT
unit 'u2' after label 'fbindz1.one' op OP_INSERT }
");
	#print "$v2";
	$ts1->clearBuffer();
	$ts2->clearBuffer();
}

# Run with an empty binding pushed on
{
	$fretz1->push($fbindz2);

	$u1->call($rop1);
	my $v1 = $ts1->print();
	ok($v1, 
"unit 'u1' before label 'lbz1' op OP_INSERT {
unit 'u1' drain label 'lbz1' op OP_INSERT
unit 'u1' before-chained label 'lbz1' op OP_INSERT
unit 'u1' before label 'fretz1.one' (chain 'lbz1') op OP_INSERT {
unit 'u1' drain label 'fretz1.one' (chain 'lbz1') op OP_INSERT
unit 'u1' after label 'fretz1.one' (chain 'lbz1') op OP_INSERT }
unit 'u1' after label 'lbz1' op OP_INSERT }
");
	#print "$v1";
	my $v2 = $ts2->print();
	ok($v2, "");
	$ts1->clearBuffer();
	$ts2->clearBuffer();
}

# pop the empty binding, back to the previous one
{
	$fretz1->pop($fbindz2);

	$u1->call($rop1);
	my $v1 = $ts1->print();
	ok($v1, 
"unit 'u1' before label 'lbz1' op OP_INSERT {
unit 'u1' drain label 'lbz1' op OP_INSERT
unit 'u1' before-chained label 'lbz1' op OP_INSERT
unit 'u1' before label 'fretz1.one' (chain 'lbz1') op OP_INSERT {
unit 'u1' drain label 'fretz1.one' (chain 'lbz1') op OP_INSERT
unit 'u1' after label 'fretz1.one' (chain 'lbz1') op OP_INSERT }
unit 'u1' after label 'lbz1' op OP_INSERT }
");
	my $v2 = $ts2->print();
	ok($v2, 
"unit 'u2' before label 'fbindz1.one' op OP_INSERT {
unit 'u2' drain label 'fbindz1.one' op OP_INSERT
unit 'u2' after label 'fbindz1.one' op OP_INSERT }
");
	#print "$v2";
	$ts1->clearBuffer();
	$ts2->clearBuffer();
}

# Pop the last binding, run again with no bindings.
{
	$fretz1->pop();

	$u1->call($rop1);
	my $v1 = $ts1->print();
	ok($v1, 
"unit 'u1' before label 'lbz1' op OP_INSERT {
unit 'u1' drain label 'lbz1' op OP_INSERT
unit 'u1' before-chained label 'lbz1' op OP_INSERT
unit 'u1' before label 'fretz1.one' (chain 'lbz1') op OP_INSERT {
unit 'u1' drain label 'fretz1.one' (chain 'lbz1') op OP_INSERT
unit 'u1' after label 'fretz1.one' (chain 'lbz1') op OP_INSERT }
unit 'u1' after label 'lbz1' op OP_INSERT }
");
	#print "$v1";
	my $v2 = $ts2->print();
	ok($v2, "");
	$ts1->clearBuffer();
	$ts2->clearBuffer();
}

######################### 
# Push/pop error handling.

# XXX this actually returns an undef - change the typemap to confess()
#eval { $fret1->push($u1); };
#ok($@ =~ /^PLACEHOLDER/);

eval { $fret1->push($fbind4); };
ok($@ =~ /^Triceps::FnReturn::push: invalid arguments:
  Attempted to push a mismatching binding on the FnReturn 'fret1'./);

eval { $fret1->pop($fbind4); };
ok($@ =~ /^Triceps::FnReturn::pop: invalid arguments:
  Triceps API violation: attempted to pop from an empty FnReturn/);
#print "$@";

eval { $fret1->pop(); };
ok($@ =~ /^Triceps::FnReturn::pop: invalid arguments:
  Triceps API violation: attempted to pop from an empty FnReturn/);
#print "$@";

$fret1->push($fbind3); # this is of the same row set type, so it's OK

eval { $fret1->pop($fbind4); };
ok($@ =~ /^Triceps::FnReturn::pop: invalid arguments:
  Triceps API violation: popping an unexpected binding./);
#print "$@";

$fret1->pop(); # restore the balance
