#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for App handling.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl App.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;
use strict;

use Test;
BEGIN { plan tests => 4 };
use Triceps;
ok(4); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");
	my $a1x = Triceps::App::find("a1");
	ok(ref $a1x, "Triceps::App");
	ok($a1->same($a1x));
}
