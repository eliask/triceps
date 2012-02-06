#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The basic example of a window (nested FIFO index).

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
	$result .= $_; # have the inputs overlap in result, as on screen
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

sub doWindow {

my $uTrades = Triceps::Unit->new("uTrades") or die "$!";
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

my $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
			->addSubIndex("last2",
				Triceps::IndexType->newFifo(limit => 2)
			)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# remember the index type by symbol, for searching on it
my $itSymbol = $ttWindow->findSubIndex("bySymbol") or die "$!";
# remember the FIFO index, for finding the start of the group
my $itLast2 = $itSymbol->findSubIndex("last2") or die "$!";

# print out the changes to the table as they happen
my $lbWindowPrint = $uTrades->makeLabel($rtTrade, "lbWindowPrint",
	undef, sub { # (label, rowop)
		&send(@_[1]->printP(), "\n"); # print the change
	}) or die "$!";
$tWindow->getOutputLabel()->chain($lbWindowPrint) or die "$!";

while(&readLine) {
	chomp;
	my $rTrade = $rtTrade->makeRowArray(split(/,/)) or die "$!";
	my $rhTrade = $tWindow->makeRowHandle($rTrade) or die "$!";
	$tWindow->insert($rhTrade) or die "$!"; # return of 0 is an error here
	# There are two ways to find the first record for this
	# symbol. Use one way for the symbol AAA and the other for the rest.
	my $rhFirst;
	if ($rTrade->get("symbol") eq "AAA") {
		$rhFirst = $tWindow->findIdx($itSymbol, $rTrade) or die "$!";
	} else  {
		# $rhTrade is now in the table but it's the last record
		$rhFirst = $rhTrade->firstOfGroupIdx($itLast2) or die "$!";
	}
	my $rhEnd = $rhFirst->nextGroupIdx($itLast2) or die "$!";
	&send("New contents:\n");
	for (my $rhi = $rhFirst; 
			!$rhi->same($rhEnd); $rhi = $rhi->nextIdx($itLast2)) {
		&send("  ", $rhi->getRow()->printP(), "\n");
	}
}

}; # Window

#########################
#  run the example

@input = (
	"1,AAA,10,10\n",
	"2,BBB,100,100\n",
	"3,AAA,20,20\n",
	"4,BBB,200,200\n",
	"5,AAA,30,30\n",
	"6,BBB,300,300\n",
);
$result = undef;
&doWindow();
ok($result, 
'1,AAA,10,10
tWindow.out OP_INSERT id="1" symbol="AAA" price="10" size="10" 
New contents:
  id="1" symbol="AAA" price="10" size="10" 
2,BBB,100,100
tWindow.out OP_INSERT id="2" symbol="BBB" price="100" size="100" 
New contents:
  id="2" symbol="BBB" price="100" size="100" 
3,AAA,20,20
tWindow.out OP_INSERT id="3" symbol="AAA" price="20" size="20" 
New contents:
  id="1" symbol="AAA" price="10" size="10" 
  id="3" symbol="AAA" price="20" size="20" 
4,BBB,200,200
tWindow.out OP_INSERT id="4" symbol="BBB" price="200" size="200" 
New contents:
  id="2" symbol="BBB" price="100" size="100" 
  id="4" symbol="BBB" price="200" size="200" 
5,AAA,30,30
tWindow.out OP_DELETE id="1" symbol="AAA" price="10" size="10" 
tWindow.out OP_INSERT id="5" symbol="AAA" price="30" size="30" 
New contents:
  id="3" symbol="AAA" price="20" size="20" 
  id="5" symbol="AAA" price="30" size="30" 
6,BBB,300,300
tWindow.out OP_DELETE id="2" symbol="BBB" price="100" size="100" 
tWindow.out OP_INSERT id="6" symbol="BBB" price="300" size="300" 
New contents:
  id="4" symbol="BBB" price="200" size="200" 
  id="6" symbol="BBB" price="300" size="300" 
'
);
