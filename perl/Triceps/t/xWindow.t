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
BEGIN { plan tests => 5 };
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
	$result .= $_ if defined $_; # have the inputs overlap in result, as on screen
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
# the simple window

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
		&send($_[1]->printP(), "\n"); # print the change
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

#########################
# the window with primary and secondary index

sub doSecondary {

my $uTrades = Triceps::Unit->new("uTrades") or die "$!";
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

my $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("byId", 
		Triceps::IndexType->newHashed(key => [ "id" ])
	)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
			->addSubIndex("last2",
				Triceps::IndexType->newFifo(limit => 2)
			)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
# ZZZ use local, not my, because printAverage() needs to access it,
# and here we are inside a function, not at global lever as it might seem
local $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# remember the index type by symbol, for searching on it
local $itSymbol = $ttWindow->findSubIndex("bySymbol") or die "$!";
# remember the FIFO index, for finding the start of the group
local $itLast2 = $itSymbol->findSubIndex("last2") or die "$!";

# remember, which was the last row modified
local $rLastMod;
my $lbRememberLastMod = $uTrades->makeLabel($rtTrade, "lbRememberLastMod",
	undef, sub { # (label, rowop)
		$rLastMod = $_[1]->getRow();
	}) or die "$!";
$tWindow->getOutputLabel()->chain($lbRememberLastMod) or die "$!";

# Print the average price of the symbol in the last modified row
sub printAverage # (row)
{
	return unless defined $rLastMod;
	my $rhFirst = $tWindow->findIdx($itSymbol, $rLastMod) or die "$!";
	my $rhEnd = $rhFirst->nextGroupIdx($itLast2) or die "$!";
	&send("Contents:\n");
	my $avg = ''; # ZZZ make the test warnings shut up
	my ($sum, $count);
	for (my $rhi = $rhFirst; 
			!$rhi->same($rhEnd); $rhi = $rhi->nextIdx($itLast2)) {
		&send("  ", $rhi->getRow()->printP(), "\n");
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	if ($count) {
		$avg = $sum/$count;
	}
	&send("Average price: $avg\n");
}

while(&readLine) {
	chomp;
	my @data = split(/,/);
	my $op = shift @data; # string opcode, if incorrect then will die later
	my $rTrade = $rtTrade->makeRowArray(@data) or die "$!";
	my $rowop = $tWindow->getInputLabel()->makeRowop($op, $rTrade) 
		or die "$!";
	$uTrades->call($rowop) or die "$!";
	&printAverage();
	undef $rLastMod; # clear for the next iteration
	$uTrades->drainFrame(); # just in case, for completeness
}

}; # Secondary

#########################
#  run the example

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,4,BBB,200,200\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_INSERT,6,BBB,300,300\n",
	"OP_DELETE,3\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doSecondary();
ok($result, 
'OP_INSERT,1,AAA,10,10
Contents:
  id="1" symbol="AAA" price="10" size="10" 
Average price: 10
OP_INSERT,2,BBB,100,100
Contents:
  id="2" symbol="BBB" price="100" size="100" 
Average price: 100
OP_INSERT,3,AAA,20,20
Contents:
  id="1" symbol="AAA" price="10" size="10" 
  id="3" symbol="AAA" price="20" size="20" 
Average price: 15
OP_INSERT,4,BBB,200,200
Contents:
  id="2" symbol="BBB" price="100" size="100" 
  id="4" symbol="BBB" price="200" size="200" 
Average price: 150
OP_INSERT,5,AAA,30,30
Contents:
  id="3" symbol="AAA" price="20" size="20" 
  id="5" symbol="AAA" price="30" size="30" 
Average price: 25
OP_INSERT,6,BBB,300,300
Contents:
  id="4" symbol="BBB" price="200" size="200" 
  id="6" symbol="BBB" price="300" size="300" 
Average price: 250
OP_DELETE,3
Contents:
  id="5" symbol="AAA" price="30" size="30" 
Average price: 30
OP_DELETE,5
Contents:
Average price: 
');

#########################
# the window with a manual aggregator

sub doManualAgg1 {

local $uTrades = Triceps::Unit->new("uTrades") or die "$!";
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

my $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("byId", 
		Triceps::IndexType->newHashed(key => [ "id" ])
	)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
			->addSubIndex("last2",
				Triceps::IndexType->newFifo(limit => 2)
			)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
# ZZZ use local, not my, because printAverage() needs to access it,
# and here we are inside a function, not at global lever as it might seem
local $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# remember the index type by symbol, for searching on it
local $itSymbol = $ttWindow->findSubIndex("bySymbol") or die "$!";
# remember the FIFO index, for finding the start of the group
local $itLast2 = $itSymbol->findSubIndex("last2") or die "$!";

# remember, which was the last row modified
local $rLastMod;
my $lbRememberLastMod = $uTrades->makeLabel($rtTrade, "lbRememberLastMod",
	undef, sub { # (label, rowop)
		$rLastMod = $_[1]->getRow();
	}) or die "$!";
$tWindow->getOutputLabel()->chain($lbRememberLastMod) or die "$!";

#####
# a manual aggregation: average price

local $rtAvgPrice = Triceps::RowType->new(
	symbol => "string", # symbol traded
	id => "int32", # last trade's id
	price => "float64", # avg price of the last 2 trades
) or die "$!";

# place to send the average: could be a dummy label, but to keep the
# code smalled also print the rows here, instead of in a separate label
local $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
	undef, sub { # (label, rowop)
		&send($_[1]->printP(), "\n");
	}) or die "$!";

# Send the average price of the symbol in the last modified row
sub computeAverage # (row)
{
	return unless defined $rLastMod;
	my $rhFirst = $tWindow->findIdx($itSymbol, $rLastMod) or die "$!";
	my $rhEnd = $rhFirst->nextGroupIdx($itLast2) or die "$!";
	&send("Contents:\n");
	my $avg = ''; # ZZZ make the test warnings shut up
	my ($sum, $count);
	my $rhLast;
	for (my $rhi = $rhFirst; 
			!$rhi->same($rhEnd); $rhi = $rhi->nextIdx($itLast2)) {
		&send("  ", $rhi->getRow()->printP(), "\n");
		$rhLast = $rhi;
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	if ($count) {
		$avg = $sum/$count;
		$uTrades->call($lbAverage->makeRowop(&Triceps::OP_INSERT,
			$rtAvgPrice->makeRowHash(
				symbol => $rhLast->getRow()->get("symbol"),
				id => $rhLast->getRow()->get("id"),
				price => $avg
			)
		));
	}
}

while(&readLine) {
	chomp;
	my @data = split(/,/);
	my $op = shift @data; # string opcode, if incorrect then will die later
	my $rTrade = $rtTrade->makeRowArray(@data) or die "$!";
	my $rowop = $tWindow->getInputLabel()->makeRowop($op, $rTrade) 
		or die "$!";
	$uTrades->call($rowop) or die "$!";
	&computeAverage();
	undef $rLastMod; # clear for the next iteration
	$uTrades->drainFrame(); # just in case, for completeness
}

}; # ManualAgg1

#########################
#  run the example

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_DELETE,3\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doManualAgg1();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
Contents:
  id="1" symbol="AAA" price="10" size="10" 
lbAverage OP_INSERT symbol="AAA" id="1" price="10" 
OP_INSERT,3,AAA,20,20
Contents:
  id="1" symbol="AAA" price="10" size="10" 
  id="3" symbol="AAA" price="20" size="20" 
lbAverage OP_INSERT symbol="AAA" id="3" price="15" 
OP_INSERT,5,AAA,30,30
Contents:
  id="3" symbol="AAA" price="20" size="20" 
  id="5" symbol="AAA" price="30" size="30" 
lbAverage OP_INSERT symbol="AAA" id="5" price="25" 
OP_DELETE,3
Contents:
  id="5" symbol="AAA" price="30" size="30" 
lbAverage OP_INSERT symbol="AAA" id="5" price="30" 
OP_DELETE,5
Contents:
');

#########################
# the window with a manual aggregator and a helper table

sub doManualAgg2 {

local $uTrades = Triceps::Unit->new("uTrades") or die "$!";
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

my $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("byId", 
		Triceps::IndexType->newHashed(key => [ "id" ])
	)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
			->addSubIndex("last2",
				Triceps::IndexType->newFifo(limit => 2)
			)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
# ZZZ use local, not my, because printAverage() needs to access it,
# and here we are inside a function, not at global lever as it might seem
local $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# remember the index type by symbol, for searching on it
local $itSymbol = $ttWindow->findSubIndex("bySymbol") or die "$!";
# remember the FIFO index, for finding the start of the group
local $itLast2 = $itSymbol->findSubIndex("last2") or die "$!";

# remember, which was the last row modified
local $rLastMod;
my $lbRememberLastMod = $uTrades->makeLabel($rtTrade, "lbRememberLastMod",
	undef, sub { # (label, rowop)
		$rLastMod = $_[1]->getRow();
	}) or die "$!";
$tWindow->getOutputLabel()->chain($lbRememberLastMod) or die "$!";

#####
# a manual aggregation: average price

local $rtAvgPrice = Triceps::RowType->new(
	symbol => "string", # symbol traded
	id => "int32", # last trade's id
	price => "float64", # avg price of the last 2 trades
) or die "$!";

my $ttAvgPrice = Triceps::TableType->new($rtAvgPrice)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
	)
or die "$!";
$ttAvgPrice->initialize() or die "$!";
# ZZZ use local, not my, because printAverage() needs to access it,
# and here we are inside a function, not at global lever as it might seem
local $tAvgPrice = $uTrades->makeTable($ttAvgPrice, 
	&Triceps::EM_CALL, "tAvgPrice") or die "$!";
local $lbAvgPriceHelper = $tAvgPrice->getInputLabel() or die "$!";

# place to send the average: could be a dummy label, but to keep the
# code smalled also print the rows here, instead of in a separate label
local $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
	undef, sub { # (label, rowop)
		&send($_[1]->printP(), "\n");
	}) or die "$!";
$tAvgPrice->getOutputLabel()->chain($lbAverage) or die "$!";

# Send the average price of the symbol in the last modified row
sub computeAverage2 # (row)
{
	return unless defined $rLastMod;
	my $rhFirst = $tWindow->findIdx($itSymbol, $rLastMod) or die "$!";
	my $rhEnd = $rhFirst->nextGroupIdx($itLast2) or die "$!";
	&send("Contents:\n");
	my $avg = ''; # ZZZ make the test warnings shut up
	my ($sum, $count);
	my $rhLast;
	for (my $rhi = $rhFirst; 
			!$rhi->same($rhEnd); $rhi = $rhi->nextIdx($itLast2)) {
		&send("  ", $rhi->getRow()->printP(), "\n");
		$rhLast = $rhi;
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	if ($count) {
		$avg = $sum/$count;
		$uTrades->call($lbAvgPriceHelper->makeRowop(&Triceps::OP_INSERT,
			$rtAvgPrice->makeRowHash(
				symbol => $rhLast->getRow()->get("symbol"),
				id => $rhLast->getRow()->get("id"),
				price => $avg
			)
		));
	} else {
		$uTrades->call($lbAvgPriceHelper->makeRowop(&Triceps::OP_DELETE,
			$rtAvgPrice->makeRowHash(
				symbol => $rLastMod->get("symbol"),
			)
		));
	}
}

while(&readLine) {
	chomp;
	my @data = split(/,/);
	my $op = shift @data; # string opcode, if incorrect then will die later
	my $rTrade = $rtTrade->makeRowArray(@data) or die "$!";
	my $rowop = $tWindow->getInputLabel()->makeRowop($op, $rTrade) 
		or die "$!";
	$uTrades->call($rowop) or die "$!";
	&computeAverage2();
	undef $rLastMod; # clear for the next iteration
	$uTrades->drainFrame(); # just in case, for completeness
}

}; # ManualAgg2

#########################
#  run the example

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_DELETE,3\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doManualAgg2();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
Contents:
  id="1" symbol="AAA" price="10" size="10" 
tAvgPrice.out OP_INSERT symbol="AAA" id="1" price="10" 
OP_INSERT,3,AAA,20,20
Contents:
  id="1" symbol="AAA" price="10" size="10" 
  id="3" symbol="AAA" price="20" size="20" 
tAvgPrice.out OP_DELETE symbol="AAA" id="1" price="10" 
tAvgPrice.out OP_INSERT symbol="AAA" id="3" price="15" 
OP_INSERT,5,AAA,30,30
Contents:
  id="3" symbol="AAA" price="20" size="20" 
  id="5" symbol="AAA" price="30" size="30" 
tAvgPrice.out OP_DELETE symbol="AAA" id="3" price="15" 
tAvgPrice.out OP_INSERT symbol="AAA" id="5" price="25" 
OP_DELETE,3
Contents:
  id="5" symbol="AAA" price="30" size="30" 
tAvgPrice.out OP_DELETE symbol="AAA" id="5" price="25" 
tAvgPrice.out OP_INSERT symbol="AAA" id="5" price="30" 
OP_DELETE,5
Contents:
tAvgPrice.out OP_DELETE symbol="AAA" id="5" price="30" 
');
