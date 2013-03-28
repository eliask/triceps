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
use threads;

use Test;
BEGIN { plan tests => 23 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");
	my $a1x = Triceps::App::find("a1");
	ok(ref $a1x, "Triceps::App");
	ok($a1->same($a1x));

	ok($a1->getName(), "a1");

	my @apps;
	@apps = Triceps::App::listApps();
	ok($#apps, 1);
	ok($apps[0], "a1");
	ok($a1->same($apps[1]));
	undef @apps;

	my $t1 = threads->create(
		sub {
			my $tname = shift;
			my $a1z = Triceps::App::find($tname);
			ok(ref $a1z, "Triceps::App");
		}, "a1");
	$t1->join();

	$Test::ntest += 1; # include the tests in the thread

	# check that the references still work
	ok(ref $a1, "Triceps::App");
	ok($a1->same($a1x));

	# check the basic harvesting (more will be used in the TrieadOwner and other tests)
	ok($a1->harvestOnce(), 1); # no threads, means the app is dead
	$a1->harvester();
	$a1->harvester(die_on_abort => 0);
	ok(!defined(eval { $a1->harvester("die_on_abort"); }));
	ok($@, qr/^Usage: Triceps::App::harvester\(app, optionName, optionValue, ...\), option names and values must go in pairs/);
	ok(!defined(eval { $a1->harvester(xxx => 1); }));
	ok($@, qr/^Triceps::App::harvester: unknown option 'xxx'/);

	# drop the app from the directory of all apps
	$a1->drop();
	@apps = Triceps::App::listApps();
	ok($#apps, -1);
}

# test the drop by name
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	my @apps;
	@apps = Triceps::App::listApps();
	ok($#apps, 1);
	ok($apps[0], "a1");

	Triceps::App::drop("a1");
	@apps = Triceps::App::listApps();
	ok($#apps, -1);
}

# declareTriead() failure (the success is tested with TrieadOwner)
{
	ok(!defined(eval {Triceps::App::declareTriead("zz", "t1");}));
	ok($@, qr/^Triceps application 'zz' is not found./);
}

# the getTrieads() is tested with TrieadOwner
