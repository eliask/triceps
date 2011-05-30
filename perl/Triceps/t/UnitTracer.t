#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for UnitTracer (in C++ Unit::Tracer).

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 7 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

$ts1 = Triceps::UnitTracerStringName->new();
ok(ref $ts1, "Triceps::UnitTracerStringName");

$tp1 = Triceps::UnitTracerPerl->new();
ok(ref $tp1, "Triceps::UnitTracerPerl");

$v = $ts1->testSubclassCall();
ok($v, "UnitTracerStringName");

$v = $tp1->testSubclassCall();
ok($v, "UnitTracerPerl");

$v = $ts1->testSuperclassCall();
ok($v, 1);

$v = $tp1->testSuperclassCall();
ok($v, 1);

