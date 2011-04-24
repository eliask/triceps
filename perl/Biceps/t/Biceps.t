#
# This file is a part of Biceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for basic package loading.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 8 };
use Biceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

ok(&Biceps::SM_SCHEDULE, 0);
ok(&Biceps::SM_FORK, 1);
ok(&Biceps::SM_CALL, 2);
ok(&Biceps::SM_IGNORE, 3);

ok(&Biceps::OP_NOP, 0);
ok(&Biceps::OP_INSERT, 1);
ok(&Biceps::OP_DELETE, 2);
