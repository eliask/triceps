#
# (C) Copyright 2011 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A simple Hello World example.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 2 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################

my $result;

$hwunit = Triceps::Unit->new("hwunit") or die "$!";
$hw_rt = Triceps::RowType->new(
	greeting => "string",
	address => "string",
) or die "$!";

my $print_greeting = $hwunit->makeLabel($hw_rt, "print_greeting", undef, sub { 
	my ($label, $rowop) = @_;
	#printf "%s!\n", join(', ', $rowop->getRow()->toArray());
	$result .= sprintf "%s!\n", join(', ', $rowop->getRow()->toArray());
} ) or die "$!";

$hwunit->call($print_greeting->makeRowop(&Triceps::OP_INSERT, 
	$hw_rt->makeRowHash(
		greeting => "Hello",
		address => "world",
	)
))  or die "$!";

ok($result, "Hello, world!\n");
