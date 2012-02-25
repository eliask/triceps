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
BEGIN { plan tests => 7 };
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

my $uTrades = Triceps::Unit->new("uTrades") or die "$!";

# the input data
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

# the aggregation result
my $rtAvgPrice = Triceps::RowType->new(
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
	my $rLast = $context->last()->getRow() or die "$!";
	my $avg = $sum/$count;

	my $res = $context->resultType()->makeRowHash(
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $avg
	) or die "$!";
	$context->send($opcode, $res) or die "$!";
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
my $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
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
#  run the same input as with manual aggregation

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

#########################
# the window holding an extra record per group

sub doExtraRecord {

my $uTrades = Triceps::Unit->new("uTrades") or die "$!";

# the input data
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

# the aggregation result
my $rtAvgPrice = Triceps::RowType->new(
	symbol => "string", # symbol traded
	id => "int32", # last trade's id
	price => "float64", # avg price of the last 2 trades
) or die "$!";

# aggregation handler: recalculate the average each time the easy way
sub computeAverage2 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode == &Triceps::OP_NOP);

	my $skip = $context->groupSize()-2;
	my $sum = 0;
	my $count = 0;
	for (my $rhi = $context->begin(); !$rhi->isNull(); 
			$rhi = $context->next($rhi)) {
		if ($skip > 0) {
			$skip--;
			next;
		}
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	my $rLast = $context->last()->getRow() or die "$!";
	my $avg = $sum/$count;

	my $res = $context->resultType()->makeRowHash(
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $avg
	) or die "$!";
	$context->send($opcode, $res) or die "$!";
}

my $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("byId", 
		Triceps::IndexType->newHashed(key => [ "id" ])
	)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
		->addSubIndex("last2",
			Triceps::IndexType->newFifo(limit => 3)
			->setAggregator(Triceps::AggregatorType->new(
				$rtAvgPrice, "aggrAvgPrice", undef, \&computeAverage2)
			)
		)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# label to print the result of aggregation
my $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
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

}; # ExtraRecord

#########################
#  run the same input as with manual aggregation

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_DELETE,3\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doExtraRecord();
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
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="20" 
OP_DELETE,5
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="20" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="1" price="10" 
');

#########################
# the window holding an extra record per group and sorted by id

sub doSortById {

my $uTrades = Triceps::Unit->new("uTrades") or die "$!";

# the input data
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

# the aggregation result
my $rtAvgPrice = Triceps::RowType->new(
	symbol => "string", # symbol traded
	id => "int32", # last trade's id
	price => "float64", # avg price of the last 2 trades
) or die "$!";

# aggregation handler: recalculate the average each time the easy way
sub computeAverage3 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode == &Triceps::OP_NOP);

	my $skip = $context->groupSize()-2;
	my $sum = 0;
	my $count = 0;
	for (my $rhi = $context->begin(); !$rhi->isNull(); 
			$rhi = $context->next($rhi)) {
		if ($skip > 0) {
			$skip--;
			next;
		}
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	my $rLast = $context->last()->getRow() or die "$!";
	my $avg = $sum/$count;

	my $res = $context->resultType()->makeRowHash(
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $avg
	) or die "$!";
	$context->send($opcode, $res) or die "$!";
}

my $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("byId", 
		Triceps::IndexType->newHashed(key => [ "id" ])
	)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
		->addSubIndex("orderById",
			Triceps::SimpleOrderedIndex->new(id => "ASC",)
			->setAggregator(Triceps::AggregatorType->new(
				$rtAvgPrice, "aggrAvgPrice", undef, \&computeAverage3)
			)
		)
		->addSubIndex("last3",
			Triceps::IndexType->newFifo(limit => 3))
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# label to print the result of aggregation
my $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
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

}; # SortById

#########################
#  run the same input as with manual aggregation

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_DELETE,3\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,7,AAA,40,40\n",
);
$result = undef;
&doSortById();
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
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="20" 
OP_INSERT,3,AAA,20,20
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="20" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="25" 
OP_INSERT,7,AAA,40,40
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="25" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="7" price="35" 
');

#########################
# the aggregator that remembers the last result

sub doRememberLast {

my $uTrades = Triceps::Unit->new("uTrades") or die "$!";

# the input data
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

# the aggregation result
my $rtAvgPrice = Triceps::RowType->new(
	symbol => "string", # symbol traded
	id => "int32", # last trade's id
	price => "float64", # avg price of the last 2 trades
) or die "$!";

# aggregation handler: recalculate the average each time the easy way
sub computeAverage4 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode == &Triceps::OP_NOP);
	if ($opcode == &Triceps::OP_DELETE) {
		$context->send($opcode, $$state) or die "$!";
		return;
	}

	my $sum = 0;
	my $count = 0;
	for (my $rhi = $context->begin(); !$rhi->isNull(); 
			$rhi = $context->next($rhi)) {
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	my $rLast = $context->last()->getRow() or die "$!";
	my $avg = $sum/$count;

	my $res = $context->resultType()->makeRowHash(
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $avg
	) or die "$!";
	${$state} = $res;
	$context->send($opcode, $res) or die "$!";
}

sub initRememberLast #  (@args)
{
	my $refvar;
	return \$refvar;
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
				$rtAvgPrice, "aggrAvgPrice", \&initRememberLast, \&computeAverage4)
			)
		)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# label to print the result of aggregation
my $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
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

}; # RememberLast

#########################
#  run the same input as with manual aggregation

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,4,BBB,200,200\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_DELETE,3\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doRememberLast();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="1" price="10" 
OP_INSERT,2,BBB,100,100
tWindow.aggrAvgPrice OP_INSERT symbol="BBB" id="2" price="100" 
OP_INSERT,3,AAA,20,20
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="1" price="10" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="3" price="15" 
OP_INSERT,4,BBB,200,200
tWindow.aggrAvgPrice OP_DELETE symbol="BBB" id="2" price="100" 
tWindow.aggrAvgPrice OP_INSERT symbol="BBB" id="4" price="150" 
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
# the aggregator that remembers the last result without an extra reference

sub doRememberLastNR {

my $uTrades = Triceps::Unit->new("uTrades") or die "$!";

# the input data
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or die "$!";

# the aggregation result
my $rtAvgPrice = Triceps::RowType->new(
	symbol => "string", # symbol traded
	id => "int32", # last trade's id
	price => "float64", # avg price of the last 2 trades
) or die "$!";

# aggregation handler: recalculate the average each time the easy way
sub computeAverage5 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode == &Triceps::OP_NOP);
	if ($opcode == &Triceps::OP_DELETE) {
		$context->send($opcode, $state) or die "$!";
		return;
	}

	my $sum = 0;
	my $count = 0;
	for (my $rhi = $context->begin(); !$rhi->isNull(); 
			$rhi = $context->next($rhi)) {
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	my $rLast = $context->last()->getRow() or die "$!";
	my $avg = $sum/$count;

	my $res = $context->resultType()->makeRowHash(
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $avg
	) or die "$!";
	$_[5] = $res;
	$context->send($opcode, $res) or die "$!";
}

sub initRememberLast5 #  (@args)
{
	return undef;
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
				$rtAvgPrice, "aggrAvgPrice", \&initRememberLast5, \&computeAverage5)
			)
		)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

# label to print the result of aggregation
my $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
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

}; # RememberLastNR

#########################
#  run the same input as with manual aggregation

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,4,BBB,200,200\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_DELETE,3\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doRememberLastNR();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="1" price="10" 
OP_INSERT,2,BBB,100,100
tWindow.aggrAvgPrice OP_INSERT symbol="BBB" id="2" price="100" 
OP_INSERT,3,AAA,20,20
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="1" price="10" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="3" price="15" 
OP_INSERT,4,BBB,200,200
tWindow.aggrAvgPrice OP_DELETE symbol="BBB" id="2" price="100" 
tWindow.aggrAvgPrice OP_INSERT symbol="BBB" id="4" price="150" 
OP_INSERT,5,AAA,30,30
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="3" price="15" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="25" 
OP_DELETE,3
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="25" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="5" price="30" 
OP_DELETE,5
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="5" price="30" 
');

