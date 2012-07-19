#
# (C) Copyright 2011-2012 Sergey A. Babkin.
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
use Carp;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################
# helper functions to support either user i/o or i/o from vars

my $result;

# write a message to user
sub send # (@message)
{
	$result .= join('', @_);
}

# write a message to user, like printf
sub sendf # ($msg, $vars...)
{
	$fmt = shift;
	$result .= sprintf($fmt, @_);
}

#########################

$hwunit = Triceps::Unit->new("hwunit") or confess "$!";
$hw_rt = Triceps::RowType->new(
	greeting => "string",
	address => "string",
) or confess "$!";

my $print_greeting = $hwunit->makeLabel($hw_rt, "print_greeting", undef, sub { 
	my ($label, $rowop) = @_;
	&sendf("%s!\n", join(', ', $rowop->getRow()->toArray()));
} ) or confess "$!";

$hwunit->call($print_greeting->makeRowop(&Triceps::OP_INSERT, 
	$hw_rt->makeRowHash(
		greeting => "Hello",
		address => "world",
	)
)) or confess "$!";

ok($result, "Hello, world!\n");
