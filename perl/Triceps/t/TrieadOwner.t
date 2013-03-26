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
BEGIN { plan tests => 7 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

$| = 1;

# basic construction
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	my $to1 = Triceps::TrieadOwner->new(undef, undef, $a1, "t1", "");
	ok(ref $to1, "Triceps::TrieadOwner");

	my $to2 = Triceps::TrieadOwner->new(undef, undef, "a1", "t2", "");
	ok(ref $to2, "Triceps::TrieadOwner");

	$a1->drop();
}

# construction with an actual thread
{
	printf("XXX begin\n");

	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	printf("XXX declare\n");

	$a1->declareTriead("t1");
	printf("XXX start\n");
	my $thr1 = async {
		my $self = threads->self();
		my $tid = $self->tid();
		printf("XXX self: %s %d\n", $self, $tid);
		my $to1 = Triceps::TrieadOwner->new(undef
			, threads->self(), "a1", "t1", "");
		#my $to1 = Triceps::TrieadOwner->new(sub {
				#printf("XXX joining %d (%s)\n", $#_, join(", ", @_));
				#my $xself = threads->object($tid);
				#printf("XXX self: %s %d\n", $xself, $tid);
				#printf("XXX is_joinable=%d\n", $xself->is_joinable());
				#$xself->join();
				#printf("XXX joined\n");
			#}, threads->self(), "a1", "t1", "");

		# go through all the markings
		printf("XXX t1 constructing\n");
		$to1->markConstructed();
		$to1->markReady();
		$to1->readyReady();
		$to1->markDead();
		printf("XXX t1 dead\n");
	};

	while(!$thr1->is_joinable()) {}
	printf("XXX joining\n");
	threads->object($thr1->tid())->join();

	printf("XXX harvesting\n");
	$a1->harvester(); # this ensures that the thread had all properly completed
	ok(!$thr1->is_running());
}
