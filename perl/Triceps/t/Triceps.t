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
BEGIN { plan tests => 31 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# constants

ok(&Triceps::EM_SCHEDULE, 0);
ok(&Triceps::EM_FORK, 1);
ok(&Triceps::EM_CALL, 2);
ok(&Triceps::EM_IGNORE, 3);

ok(&Triceps::OP_NOP, 0);
ok(&Triceps::OP_INSERT, 1);
ok(&Triceps::OP_DELETE, 2);

ok(&Triceps::OCF_INSERT, 1);
ok(&Triceps::OCF_DELETE, 2);

# reverse translation of constants
ok(&Triceps::emString(&Triceps::EM_SCHEDULE), "EM_SCHEDULE");
ok(&Triceps::emString(&Triceps::EM_FORK), "EM_FORK");
ok(&Triceps::emString(&Triceps::EM_CALL), "EM_CALL");
ok(&Triceps::emString(&Triceps::EM_IGNORE), "EM_IGNORE");
ok(&Triceps::emString(999), undef);

ok(&Triceps::opcodeString(&Triceps::OP_NOP), "OP_NOP");
ok(&Triceps::opcodeString(&Triceps::OP_INSERT), "OP_INSERT");
ok(&Triceps::opcodeString(&Triceps::OP_DELETE), "OP_DELETE");
ok(&Triceps::opcodeString(0x333), "[ID]");

ok(&Triceps::ocfString(&Triceps::OCF_INSERT), "OCF_INSERT");
ok(&Triceps::ocfString(&Triceps::OCF_DELETE), "OCF_DELETE");
ok(&Triceps::ocfString(999), undef);

# tests of the opcodes

ok(&Triceps::isInsert(&Triceps::OP_INSERT));
ok(!&Triceps::isInsert(&Triceps::OP_DELETE));
ok(!&Triceps::isInsert(&Triceps::OP_NOP));

ok(!&Triceps::isDelete(&Triceps::OP_INSERT));
ok(&Triceps::isDelete(&Triceps::OP_DELETE));
ok(!&Triceps::isDelete(&Triceps::OP_NOP));

ok(!&Triceps::isNop(&Triceps::OP_INSERT));
ok(!&Triceps::isNop(&Triceps::OP_DELETE));
ok(&Triceps::isNop(&Triceps::OP_NOP));

