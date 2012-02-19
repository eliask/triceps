#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Continuation of examples from xWindow.t, now with a real aggregator.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 3 };
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
# the window with a non-additive aggregator

sub doNonAdditive {

local $uTrades = Triceps::Unit->new("uTrades") or die "$!";

# the input data
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

# the aggregation result
local $rtAvgPrice = Triceps::RowType->new(
	symbol => "string", # symbol traded
	id => "int32", # last trade's id
	price => "float64", # avg price of the last 2 trades
) or die "$!";

# aggregation handler: recalculate the average each time the easy way
sub computeAverage1 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode == &Triceps::OP_NOP);

	my $sum = 0;
	my $count = 0;
	for (my $rhi = $context->begin(); !$rhi->isNull(); 
			$rhi = $context->next($rhi)) {
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	my $rLast = $context->last()->getRow();
	my $avg = $sum/$count;

	my $res = $context->resultType()->makeRowHash(
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $avg
	);
	$context->send($opcode, $res);
}

my $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("byId", 
		Triceps::IndexType->newHashed(key => [ "id" ])
	)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
		->addSubIndex("last2",
			Triceps::IndexType->newFifo(limit => 2)
			->setAggregator(Triceps::AggregatorType->new(
				$rtAvgPrice, "aggrAvgPrice", undef, \&computeAverage1)
			)
		)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# label to print the result of aggregation
local $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
	undef, sub { # (label, rowop)
		&send($_[1]->printP(), "\n");
	}) or die "$!";
$tWindow->getAggregatorLabel("aggrAvgPrice")->chain($lbAverage)
	or die "$!";

while(&readLine) {
	chomp;
	my @data = split(/,/); # starts with a string opcode
	$uTrades->makeArrayCall($tWindow->getInputLabel(), @data)
		or die "$!";
	$uTrades->drainFrame(); # just in case, for completeness
}

}; # NonAdditive

#########################
#  run the same input as with additive aggregation

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_DELETE,3\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doNonAdditive();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="1" price="10" 
OP_INSERT,3,AAA,20,20
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="1" price="10" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="3" price="15" 
OP_INSERT,5,AAA,30,30
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="3" price="15" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="25" 
OP_DELETE,3
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="25" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="30" 
OP_DELETE,5
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="30" 
');

#########################
#  demonstrate no missing DELETE

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_INSERT,5,BBB,30,30\n",
	"OP_INSERT,7,AAA,40,40\n",
);
$result = undef;
&doNonAdditive();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="1" price="10" 
OP_INSERT,3,AAA,20,20
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="1" price="10" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="3" price="15" 
OP_INSERT,5,AAA,30,30
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="3" price="15" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="25" 
OP_INSERT,5,BBB,30,30
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="25" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="3" price="20" 
tWindow.aggrAvgPrice OP_INSERT symbol="BBB" id="5" price="30" 
OP_INSERT,7,AAA,40,40
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="3" price="20" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="7" price="30" 
');

