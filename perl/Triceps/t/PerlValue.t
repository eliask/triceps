#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for PerlSortedIndexType's interaction with threads.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 36 };
use Triceps;
use Carp;
use strict;
ok(1); # If we made it this far, we're ok.

#########################

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

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my($v, $res);

$v = Triceps::PerlValue->new(undef);
ok(ref $v, "Triceps::PerlValue");
$res = $v->get();
ok(!defined $res);

$v = Triceps::PerlValue->new(1);
$res = $v->get();
ok($res, 1);

$v = Triceps::PerlValue->new(1.5);
$res = $v->get();
ok($res, 1.5);

$v = Triceps::PerlValue->new("xxx");
$res = $v->get();
ok($res, "xxx");

$v = Triceps::PerlValue->new($rt1);
$res = $v->get();
ok(ref $res, "Triceps::RowType");
ok($res->equals($rt1));
ok(!$res->same($rt1));

$v = Triceps::PerlValue->new([]);
$res = $v->get();
ok(ref $res, "ARRAY");
ok($#$res, -1);

$v = Triceps::PerlValue->new([1, 1.5, "xxx"]);
$res = $v->get();
ok(ref $res, "ARRAY");
ok($#$res, 2);
ok($$res[0], 1);
ok($$res[1], 1.5);
ok($$res[2], "xxx");

$v = Triceps::PerlValue->new({});
$res = $v->get();
ok(ref $res, "HASH");
ok(join(' ', sort(keys %$res)), "");

$v = Triceps::PerlValue->new({ a => 1,  b=> 1.5,  c => "xxx" });
$res = $v->get();
ok(ref $res, "HASH");
ok(join(' ', sort(keys %$res)), "a b c");
ok($$res{a}, 1);
ok($$res{b}, 1.5);
ok($$res{c}, "xxx");

# double-nested
$v = Triceps::PerlValue->new([$rt1, { a => 1,  b=> 1.5,  c => "xxx" }]);
$res = $v->get();
ok(ref $res, "ARRAY");
ok($#$res, 1);
ok(ref $$res[0], "Triceps::RowType");
ok($$res[0]->equals($rt1));
ok(join(' ', sort(keys %{$$res[1]})), "a b c");

# multiple row references preserve the commonality
$v = Triceps::PerlValue->new([$rt1, $rt1, $rt1]);
$res = $v->get();
ok($$res[0]->equals($rt1));
ok(!$$res[0]->same($rt1));
ok($$res[0]->same($$res[1]));
ok($$res[0]->same($$res[2]));

#########################
# test the errors

eval { Triceps::PerlValue->new(sub {}); };
ok($@, qr/^to allow passing between the threads, the value must be one of undef, int, float, string, RowType, or an array of hash thereof/);

eval { Triceps::PerlValue->new([sub {}]); };
ok($@, qr/^invalid value at array index 0:\n  to allow passing between the threads, the value must be one of undef, int, float, string, RowType, or an array of hash thereof/);

eval { Triceps::PerlValue->new({ a => sub {}}); };
ok($@, qr/^invalid value at hash key 'a':\n  to allow passing between the threads, the value must be one of undef, int, float, string, RowType, or an array of hash thereof/);

