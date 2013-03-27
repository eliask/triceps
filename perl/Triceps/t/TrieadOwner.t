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
BEGIN { plan tests => 9 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# basic construction (and along the way App::declareTriead)
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	$a1->declareTriead("t1");
	my $to1 = Triceps::TrieadOwner->new(undef, $a1, "t1", "");
	ok(ref $to1, "Triceps::TrieadOwner");

	Triceps::App::declareTriead("a1", "t1");
	my $to2 = Triceps::TrieadOwner->new(undef, "a1", "t2", "");
	ok(ref $to2, "Triceps::TrieadOwner");

	$a1->drop();
}

# construction with an actual thread
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	$a1->declareTriead("t1");
	my $thr1 = async {
		my $self = threads->self();
		my $tid = $self->tid();
		my $to1 = Triceps::TrieadOwner->new($tid, "a1", "t1", "");

		# go through all the markings
		$to1->markConstructed();
		$to1->markReady();
		$to1->readyReady();
		$to1->markDead();
	};

	$a1->harvester(); # this ensures that the thread had all properly completed
	ok(!$thr1->is_running());
}

# construction with Triead::start
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	Triceps::Triead::start(
		app => "a1",
		thread => "t1",
		main => sub {
			ok(1);
		},
	);
		
	$a1->harvester(); # this ensures that the thread had all properly completed
	$Test::ntest = 9; # include the tests in the thread
	ok(1);
}
