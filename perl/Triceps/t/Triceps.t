#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for basic package loading.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 8 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

ok(&Triceps::SM_SCHEDULE, 0);
ok(&Triceps::SM_FORK, 1);
ok(&Triceps::SM_CALL, 2);
ok(&Triceps::SM_IGNORE, 3);

ok(&Triceps::OP_NOP, 0);
ok(&Triceps::OP_INSERT, 1);
ok(&Triceps::OP_DELETE, 2);
