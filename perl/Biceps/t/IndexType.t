#
# This file is a part of Biceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for IndexType.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Biceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 23 };
use Biceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

###################### new_hashed #################################

$it1 = Biceps::IndexType->new_hashed(key => [ "a", "b" ]);
ok(ref $it1, "Biceps::IndexType");
$res = $it1->print();
ok($res, "HashedIndex(a, b, )");

$it1 = Biceps::IndexType->new_hashed("key");
ok(!defined($it1));
ok($! . "", "Usage: Biceps::IndexType::new_hashed(CLASS, optionName, optionValue, ...), option names and values must go in pairs");

$it1 = Biceps::IndexType->new_hashed(zzz => [ "a", "b" ]);
ok(!defined($it1));
ok($! . "", "Biceps::IndexType::new_hashed: unknown option 'zzz'");

$it1 = Biceps::IndexType->new_hashed(key => [ "a", "b" ], key => ["c"]);
ok(!defined($it1));
ok($! . "", "Biceps::IndexType::new_hashed: option 'key' can not be used twice");

$it1 = Biceps::IndexType->new_hashed(key => { "a", "b" });
ok(!defined($it1));
ok($! . "", "Biceps::IndexType::new_hashed: option 'key' value must be an array reference");

$it1 = Biceps::IndexType->new_hashed(key => undef);
ok(!defined($it1));
ok($! . "", "Biceps::IndexType::new_hashed: option 'key' value must be an array reference");

$it1 = Biceps::IndexType->new_hashed();
ok(!defined($it1));
ok($! . "", "Biceps::IndexType::new_hashed: the required option 'key' is missing");

###################### new_fifo #################################

$it1 = Biceps::IndexType->new_fifo();
ok(ref $it1, "Biceps::IndexType");
$res = $it1->print();
ok($res, "FifoIndex()");

$it1 = Biceps::IndexType->new_fifo(limit => 10, jumping => 1);
ok(ref $it1, "Biceps::IndexType");
$res = $it1->print();
ok($res, "FifoIndex(limit=10 jumping)");

$it1 = Biceps::IndexType->new_fifo("key");
ok(!defined($it1));
ok($! . "", "Usage: Biceps::IndexType::new_fifo(CLASS, optionName, optionValue, ...), option names and values must go in pairs");

$it1 = Biceps::IndexType->new_fifo(zzz => [ "a", "b" ]);
ok(!defined($it1));
ok($! . "", "Biceps::IndexType::new_fifo: unknown option 'zzz'");

