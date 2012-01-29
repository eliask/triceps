#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Simple "Hello world" examples for a table.

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
# helper functions to support either user i/o or i/o from vars

# vars to serve as input and output sources
my @input;
my $result;

# simulates user input: returns the next line or undef
sub readLine # ()
{
	$_ = shift @input;
	return $_;
}

# write a message to user
sub send # (@message)
{
	$result .= join('', @_);
}

# versions for the real user interaction
sub readLineX # ()
{
	$_ = <STDIN>;
	return $_;
}

sub sendX # (@message)
{
	print @_;
}

#########################
# Example with the direct table ops

sub helloWorldDirect()
{
	my $hwunit = Triceps::Unit->new("hwunit") or die "$!";
	my $rtCount = Triceps::RowType->new(
		address => "string",
		count => "int32",
	) or die "$!";

	my $ttCount = Triceps::TableType->new($rtCount)
		->addSubIndex("byAddress", 
			Triceps::IndexType->newHashed(key => [ "address" ])
		)
	or die "$!";
	$ttCount->initialize() or die "$!";

	my $tCount = $hwunit->makeTable($ttCount, &Triceps::EM_CALL, "tCount") or die "$!";

	while(&readLine()) {
		chomp;
		my @data = split(/\W+/);

		# the common part: find if there already is a count for this address
		my $pattern = $rtCount->makeRowHash(
			address => $data[1]
		) or die "$!";
		my $rhFound = $tCount->find($pattern) or die "$!";
		my $cnt = 0;
		if (!$rhFound->isNull()) {
			$cnt = $rhFound->getRow()->get("count");
		}

		if ($data[0] =~ /^hello$/i) {
			my $new = $rtCount->makeRowHash(
				address => $data[1],
				count => $cnt+1,
			) or die "$!";
			$tCount->insert($new) or die "$!";
		} elsif ($data[0] =~ /^count$/i) {
			&send("Received '", $data[1], "' ", $cnt + 0, " times\n");
		} else {
			&send("Unknown command '$data[0]'\n");
		}
	}
}

#########################
# test the last example

@input = (
	"Hello, table!\n",
	"Hello, world!\n",
	"Hello, table!\n",
	"count world\n",
	"Count table\n",
	"goodbye, world\n",
);
$result = undef;
&helloWorldDirect();
ok($result, 
	"Received 'world' 1 times\n" .
	"Received 'table' 2 times\n" .
	"Unknown command 'goodbye'\n"
)
