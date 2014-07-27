#
# (C) Copyright 2011-2014 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for streaming functions: FnReturn, FnBinding etc.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 16 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $res;
my $codeClosure = sub { return "testClosure"; };
my $codeString = 'return "testString";';

$res = Triceps::Code::compile(undef);
ok(!defined $res);

$res = Triceps::Code::compile($codeClosure);
ok($res, $codeClosure);
ok(&$res(), "testClosure");

$res = Triceps::Code::compile($codeString);
ok(ref $res, "CODE");
ok(&$res(), "testString");

# an integer gets converted to a string which ends up as a function returning
# that integer
$res = Triceps::Code::compile(1);
ok(ref $res, "CODE");
ok(&$res(), 1);

$res = eval { Triceps::Code::compile("1 ) 2"); };
ok(!defined $res);
ok("$@", qr/Code snippet: failed to compile the source code\nCompilation error: syntax error at .*\nThe source code was:\nsub {\n1 \) 2\n}\n at .*\/Code.pm line \d*\n\tTriceps::Code::compile\('1 \) 2'\) called at .*\/Code.t line \d*\n\teval {...} called at .*\/Code.t line \d*\n/);
#print $@;

$res = eval { Triceps::Code::compile("1 ) 2", "test code"); };
ok(!defined $res);
ok("$@", qr/^test code: failed to compile the source code\nCompilation error: syntax error at .*\nThe source code was:\nsub \{\n1 \) 2\n\}\n at .*\/Code.pm line \d*\n\tTriceps::Code::compile\('1 \) 2', 'test code'\) called at .*\/Code.t line \d*\n\teval {...} called at .*\/Code.t line \d*\n/);
#print $@;

# a completely wrong value
$res = eval { Triceps::Code::compile([1, 2]); };
ok(!defined $res);
ok("$@", qr/^Code snippet: code must be a source code string or a reference to Perl function at/);

# a completely wrong value, with custom name
$res = eval { Triceps::Code::compile([1, 2], "test code"); };
ok(!defined $res);
ok("$@", qr/^test code: code must be a source code string or a reference to Perl function at/);

