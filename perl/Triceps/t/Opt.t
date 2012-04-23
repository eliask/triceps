#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Test of the option parsing sub-package.

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 45 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $optdef =  {
	mand => [ undef, \&Triceps::Opt::ck_mandatory ],
	opt => [ 9, undef ],
	veryopt => [ undef, undef ],
};

my $testobj = {};

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef,
		mand => 1, opt => 2, veryopt => 3);
};
ok(!$@);
ok($testobj->{mand}, 1);
ok($testobj->{opt}, 2);
ok($testobj->{veryopt}, 3);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef,
		mand => 9);
};
ok(!$@);
ok($testobj->{mand}, 9);
ok($testobj->{opt}, 9);
ok(!defined $testobj->{veryopt});

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef,
		mand => 9, zzz => 99);
};
ok($@ =~ /^Unknown option 'zzz' for class 'MYCLASS' at .*/);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef,
		mand => 9, "zzz");
};
ok($@ =~ /^Last option 'mand' for class 'MYCLASS' is without a value at .*/);

$testobj = {};
eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef,
		opt => 9);
};
ok($@ =~ /^Option 'mand' must be specified for class 'MYCLASS' at .*/);

# test ck_ref

my $optdef2 =  {
	unit => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
	arrunit => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY", "Triceps::Unit") } ],
	hashunit => [ undef, sub { &Triceps::Opt::ck_ref(@_, "HASH", "Triceps::Unit") } ],
	unitunit => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Unit", "Triceps::Unit") } ],
};

my $u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef2,
		unit => $u1);
};
ok(!$@);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef2,
		arrunit => [ $u1 ] );
};
ok(!$@);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef2,
		hashunit => { key => $u1 } );
};
ok(!$@);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef2,
		hashunit => { key => "value" } );
};
ok($@ =~ /^Option 'hashunit' of class 'MYCLASS' must be a reference to 'HASH' 'Triceps::Unit', is 'HASH' ''.*/);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef2,
		arrunit => [ { key => "value" } ] );
};
#print STDERR "$@\n";
ok($@ =~ /^Option 'arrunit' of class 'MYCLASS' must be a reference to 'ARRAY' 'Triceps::Unit', is 'ARRAY' 'HASH'.*/);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef2,
		unit => { key => $u1 } );
};
ok($@ =~ /^Option 'unit' of class 'MYCLASS' must be a reference to 'Triceps::Unit', is 'HASH'.*/);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef2,
		unitunit => $u1);
};
ok($@ =~ /^Incorrect arguments, may use the second type only if the first is ARRAY or HASH.*/);

# test ck_refscalar

my $optdef3 =  {
	unit => [ undef, sub { &Triceps::Opt::ck_refscalar(@_) } ],
};

eval {
	my $v;
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef3,
		unit => \$v);
};
ok(!$@);

eval {
	my $v = 1;
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef3,
		unit => \$v);
};
ok(!$@);

eval {
	my $v = [ 1 ];
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef3,
		unit => \$v);
};
ok(!$@);

eval {
	Triceps::Opt::parse(MYCLASS, $testobj, $optdef3,
		unit => $u1);
};
ok($@ =~ /^Option 'unit' of class 'MYCLASS' must be a reference to a scalar, is 'Triceps::Unit'.*/);

#########################
# handleUnitTypeLabel

{
	my $u1 = Triceps::Unit->new("u1");
	ok(ref $u1, "Triceps::Unit");
	my $u2 = Triceps::Unit->new("u2");
	ok(ref $u2, "Triceps::Unit");
	my $rt1 = Triceps::RowType->new(
		a => "uint8",
		b => "int32",
	);
	ok(ref $rt1, "Triceps::RowType");
	my $lb1 = $u1->makeDummyLabel($rt1, "lb1");
	ok(ref $lb1, "Triceps::Label");
	my $lb2 = $u2->makeDummyLabel($rt1, "lb2");
	ok(ref $lb2, "Triceps::Label");
	my ($unit, $rt, $label);

	($unit, $rt, $label) = (undef, undef, undef);
	eval { &Triceps::Opt::handleUnitTypeLabel("CallerMethod", "unitX", \$unit, "rowTypeX", \$rt, "labelX", \$label); };
	ok($@ =~ /^CallerMethod: must have exactly one of options rowTypeX or labelX/);

	($unit, $rt, $label) = (undef, $rt1, undef);
	eval { &Triceps::Opt::handleUnitTypeLabel("CallerMethod", "unitX", \$unit, "rowTypeX", \$rt, "labelX", \$label); };
	ok($@ =~ /^CallerMethod: option unitX must be specified/);

	($unit, $rt, $label) = ($u1, $rt1, $lb1);
	eval { &Triceps::Opt::handleUnitTypeLabel("CallerMethod", "unitX", \$unit, "rowTypeX", \$rt, "labelX", \$label); };
	ok($@ =~ /^CallerMethod: must have only one of options rowTypeX or labelX/);

	($unit, $rt, $label) = ($u1, $rt1, undef);
	&Triceps::Opt::handleUnitTypeLabel("CallerMethod", "unitX", \$unit, "rowTypeX", \$rt, "labelX", \$label);
	
	($unit, $rt, $label) = (undef, undef, $lb1);
	&Triceps::Opt::handleUnitTypeLabel("CallerMethod", "unitX", \$unit, "rowTypeX", \$rt, "labelX", \$label);
	ok($u1->same($unit));
	ok($rt1->same($rt));
	
	($unit, $rt, $label) = ($u1, undef, $lb1);
	&Triceps::Opt::handleUnitTypeLabel("CallerMethod", "unitX", \$unit, "rowTypeX", \$rt, "labelX", \$label);
	ok($u1->same($unit));
	ok($rt1->same($rt));
	
	($unit, $rt, $label) = ($u1, undef, $lb2);
	eval { &Triceps::Opt::handleUnitTypeLabel("CallerMethod", "unitX", \$unit, "rowTypeX", \$rt, "labelX", \$label); };
	ok($@ =~ /^CallerMethod: the label 'lb2' in option labelX has a mismatched unit \('u2' vs 'u1'\)/);

}

#########################
# checkMutuallyExclusive
{
	my $res;

	$res = &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 0, "opt1", undef, "opt2", undef, "opt3", undef);
	ok(!defined $res);
	$res = &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 0, "opt1", 9, "opt2", undef, "opt3", undef);
	ok($res, "opt1");
	$res = &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 0, "opt1", undef, "opt2", undef, "opt3", 0);
	ok($res, "opt3");
	$res = &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 1, "opt1", 9, "opt2", undef, "opt3", undef);
	ok($res, "opt1");
	$res = &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 1, "opt1", undef, "opt2", undef, "opt3", 0);
	ok($res, "opt3");

	$res = eval { &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 0, "opt1", 9, "opt2", 0, "opt3", undef); };
	ok($@ =~ /CallerMethod: must have only one of options opt1 or opt2 or opt3, got opt1 and opt2/);
	$res = eval { &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 1, "opt1", 9, "opt2", 0, "opt3", 0); };
	ok($@ =~ /CallerMethod: must have only one of options opt1 or opt2 or opt3, got opt1 and opt2 and opt3/);
	$res = eval { &Triceps::Opt::checkMutuallyExclusive("CallerMethod", 1, "opt1", undef, "opt2", undef, "opt3", undef); };
	ok($@ =~ /CallerMethod: must have exactly one of options opt1 or opt2 or opt3, got none of them/);
}

#print STDERR "$@\n";
