#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Test of the option parsing sub-package.

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 12 };
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
ok(!defined $testobj->{opt});
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

