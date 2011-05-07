#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for IndexType.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 53 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

###################### newHashed #################################

$it1 = Triceps::IndexType->newHashed(key => [ "a", "b" ]);
ok(ref $it1, "Triceps::IndexType");
$res = $it1->print();
ok($res, "HashedIndex(a, b, )");

$it1 = Triceps::IndexType->newHashed("key");
ok(!defined($it1));
ok($! . "", "Usage: Triceps::IndexType::newHashed(CLASS, optionName, optionValue, ...), option names and values must go in pairs");

$it1 = Triceps::IndexType->newHashed(zzz => [ "a", "b" ]);
ok(!defined($it1));
ok($! . "", "Triceps::IndexType::newHashed: unknown option 'zzz'");

$it1 = Triceps::IndexType->newHashed(key => [ "a", "b" ], key => ["c"]);
ok(!defined($it1));
ok($! . "", "Triceps::IndexType::newHashed: option 'key' can not be used twice");

$it1 = Triceps::IndexType->newHashed(key => { "a", "b" });
ok(!defined($it1));
ok($! . "", "Triceps::IndexType::newHashed: option 'key' value must be an array reference");

$it1 = Triceps::IndexType->newHashed(key => undef);
ok(!defined($it1));
ok($! . "", "Triceps::IndexType::newHashed: option 'key' value must be an array reference");

$it1 = Triceps::IndexType->newHashed();
ok(!defined($it1));
ok($! . "", "Triceps::IndexType::newHashed: the required option 'key' is missing");

###################### newFifo #################################

$it1 = Triceps::IndexType->newFifo();
ok(ref $it1, "Triceps::IndexType");
$res = $it1->print();
ok($res, "FifoIndex()");

$it1 = Triceps::IndexType->newFifo(limit => 10, jumping => 1);
ok(ref $it1, "Triceps::IndexType");
$res = $it1->print();
ok($res, "FifoIndex(limit=10 jumping)");

$it1 = Triceps::IndexType->newFifo("key");
ok(!defined($it1));
ok($! . "", "Usage: Triceps::IndexType::newFifo(CLASS, optionName, optionValue, ...), option names and values must go in pairs");

$it1 = Triceps::IndexType->newFifo(zzz => [ "a", "b" ]);
ok(!defined($it1));
ok($! . "", "Triceps::IndexType::newFifo: unknown option 'zzz'");

###################### equality #################################

$it1 = Triceps::IndexType->newHashed(key => [ "a", "b" ]);
ok(ref $it1, "Triceps::IndexType");
$it2 = Triceps::IndexType->newHashed(key => [ "a", "b" ]);
ok(ref $it2, "Triceps::IndexType");
$it3 = Triceps::IndexType->newHashed(key => [ "c", "d" ]);
ok(ref $it3, "Triceps::IndexType");
$it4 = Triceps::IndexType->newHashed(key => [ "e" ]);
ok(ref $it4, "Triceps::IndexType");
$it5 = Triceps::IndexType->newFifo();
ok(ref $it5, "Triceps::IndexType");

$res = $it1->equals($it2);
ok($res, 1);
$res = $it1->equals($it3);
ok($res, 0);
$res = $it1->equals($it4);
ok($res, 0);
$res = $it1->equals($it5);
ok($res, 0);

$res = $it1->match($it2);
ok($res, 1);
$res = $it1->match($it3);
ok($res, 0);
$res = $it1->match($it4);
ok($res, 0);
$res = $it1->match($it5);
ok($res, 0);

###################### nested #################################

# reuse $it1..$it5 from the last tests, modify them

$it2 = $it2->addNested(level2 => $it3->addNested(level3 => $it5));
ok(ref $it2, "Triceps::IndexType");
$res = $it1->equals($it2);
ok($res, 0);
$res = $it1->match($it2);
ok($res, 0);
$res = $it2->print();
ok($res, "HashedIndex(a, b, ) {\n  HashedIndex(c, d, ) {\n    FifoIndex() level3,\n  } level2,\n}");

$res = $it1->isLeaf();
ok($res, 1);
$res = $it2->isLeaf();
ok($res, 0);
$res = $it3->isLeaf(); 
ok($res, 0);

$res = $it2->findNested("level2");
ok(ref $it2, "Triceps::IndexType");
$res = $res->equals($it3);
ok($res, 1);

$res = $it2->findNested("xxx");
ok(!defined($res));
ok($! . "", "Triceps::IndexType::findNested: unknown nested index 'xxx'");

$it6 = $it2->findNested("level2")->findNested("level3");
ok(ref $it6, "Triceps::IndexType");
$res = $it6->equals($it5);
ok($res, 1);
$res = $it6->print();
ok($res, "FifoIndex()");

$it6 = $it2->getFirstLeaf();
ok(ref $it6, "Triceps::IndexType");
$res = $it6->equals($it5);

$it6 = $it5->getFirstLeaf();
ok(ref $it6, "Triceps::IndexType");
$res = $it6->equals($it5);

###################### nested #################################

$res = $it2->isInitialized();
ok($res, 0);
