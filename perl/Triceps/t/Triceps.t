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
BEGIN { plan tests => 67 };
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

ok(&Triceps::TW_BEFORE, 0);
ok(&Triceps::TW_BEFORE_DRAIN, 1);
ok(&Triceps::TW_BEFORE_CHAINED, 2);
ok(&Triceps::TW_AFTER, 3);

# translation of constant strings

ok(&Triceps::stringEm("EM_SCHEDULE"), &Triceps::EM_SCHEDULE);
ok(&Triceps::stringEm("EM_FORK"), &Triceps::EM_FORK);
ok(&Triceps::stringEm("EM_CALL"), &Triceps::EM_CALL);
ok(&Triceps::stringEm("EM_IGNORE"), &Triceps::EM_IGNORE);
ok(&Triceps::stringEm("xxx"), undef);

ok(&Triceps::stringOpcode("OP_NOP"), &Triceps::OP_NOP);
ok(&Triceps::stringOpcode("OP_INSERT"), &Triceps::OP_INSERT);
ok(&Triceps::stringOpcode("OP_DELETE"), &Triceps::OP_DELETE);
ok(&Triceps::stringOpcode("xxx"), undef);

ok(&Triceps::stringOcf("OCF_INSERT"), &Triceps::OCF_INSERT);
ok(&Triceps::stringOcf("OCF_DELETE"), &Triceps::OCF_DELETE);
ok(&Triceps::stringOcf("xxx"), undef);

ok(&Triceps::stringTracerWhen("TW_BEFORE"), &Triceps::TW_BEFORE);
ok(&Triceps::stringTracerWhen("TW_BEFORE_DRAIN"), &Triceps::TW_BEFORE_DRAIN);
ok(&Triceps::stringTracerWhen("TW_BEFORE_CHAINED"), &Triceps::TW_BEFORE_CHAINED);
ok(&Triceps::stringTracerWhen("TW_AFTER"), &Triceps::TW_AFTER);
ok(&Triceps::stringTracerWhen("xxx"), undef);

ok(&Triceps::humanStringTracerWhen("before"), &Triceps::TW_BEFORE);
ok(&Triceps::humanStringTracerWhen("drain"), &Triceps::TW_BEFORE_DRAIN);
ok(&Triceps::humanStringTracerWhen("before-chained"), &Triceps::TW_BEFORE_CHAINED);
ok(&Triceps::humanStringTracerWhen("after"), &Triceps::TW_AFTER);
ok(&Triceps::humanStringTracerWhen("xxx"), undef);

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

ok(&Triceps::tracerWhenString(&Triceps::TW_BEFORE), "TW_BEFORE");
ok(&Triceps::tracerWhenString(&Triceps::TW_BEFORE_DRAIN), "TW_BEFORE_DRAIN");
ok(&Triceps::tracerWhenString(&Triceps::TW_BEFORE_CHAINED), "TW_BEFORE_CHAINED");
ok(&Triceps::tracerWhenString(&Triceps::TW_AFTER), "TW_AFTER");
ok(&Triceps::tracerWhenString(999), undef);

ok(&Triceps::tracerWhenHumanString(&Triceps::TW_BEFORE), "before");
ok(&Triceps::tracerWhenHumanString(&Triceps::TW_BEFORE_DRAIN), "drain");
ok(&Triceps::tracerWhenHumanString(&Triceps::TW_BEFORE_CHAINED), "before-chained");
ok(&Triceps::tracerWhenHumanString(&Triceps::TW_AFTER), "after");
ok(&Triceps::tracerWhenHumanString(999), undef);

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

