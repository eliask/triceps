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
BEGIN { plan tests => 4 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################


# construction
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	my $to1 = Triceps::TrieadOwner->new($a1, "t1", "");
	ok(ref $to1, "Triceps::TrieadOwner");

	my $to2 = Triceps::TrieadOwner->new("a1", "t2", "");
	ok(ref $to2, "Triceps::TrieadOwner");

	$a1->drop();
}
