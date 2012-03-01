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
BEGIN { plan tests => 14 };
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

#########################
# the aggregator that performs the simple additive aggrgeation
# and carries all the state

sub doSimpleAdditiveState {

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
sub computeAverage7 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;
	my $rowchg;
	
	#print STDERR &Triceps::aggOpString($aggop), " ", &Triceps::opcodeString($opcode), " ", (!$rh->isNull()? $rh->getRow()->printP(): "NULL"), "\n";
	if ($aggop == &Triceps::AO_BEFORE_MOD) { 
		$context->send($opcode, $state->{lastrow}) or die "$!";
		return;
	} elsif ($aggop == &Triceps::AO_AFTER_DELETE) { 
		$rowchg = -1;
	} elsif ($aggop == &Triceps::AO_AFTER_INSERT) { 
		$rowchg = 1;
	} else { # AO_COLLAPSE, also has opcode OP_DELETE
		return
	}

	$state->{price_sum} += $rowchg * $rh->getRow()->get("price");

	return if ($context->groupSize()==0
		|| $opcode == &Triceps::OP_NOP);

	my $rLast = $context->last()->getRow() or die "$!";
	my $count = $context->groupSize();
	my $avg = $state->{price_sum}/$count;
	my $res = $context->resultType()->makeRowHash(
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $avg
	) or die "$!";
	$state->{lastrow} = $res;

	$context->send($opcode, $res) or die "$!";
}

sub initAverage7 #  (@args)
{
	return { lastrow => undef, price_sum => 0 };
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
				$rtAvgPrice, "aggrAvgPrice", \&initAverage7, \&computeAverage7)
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

}; # SimpleAdditiveState

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
&doSimpleAdditiveState();
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
#  demonstrate the precision loss

@input = (
	"OP_INSERT,1,AAA,1,10\n",
	"OP_INSERT,2,AAA,1e20,20\n",
	"OP_INSERT,3,AAA,2,10\n",
	"OP_INSERT,4,AAA,3,10\n",
);
$result = undef;
&doSimpleAdditiveState();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,1,10
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="1" price="1" 
OP_INSERT,2,AAA,1e20,20
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="1" price="1" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="2" price="5e+19" 
OP_INSERT,3,AAA,2,10
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="2" price="5e+19" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="3" price="5e+19" 
OP_INSERT,4,AAA,3,10
tWindow.aggrAvgPrice OP_DELETE symbol="AAA" id="3" price="5e+19" 
tWindow.aggrAvgPrice OP_INSERT symbol="AAA" id="4" price="1.5" 
');

#########################
# the aggregator that performs the simple additive aggrgeation
# and does not remember the last row.

sub doSimpleAdditiveNoLast {

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
sub computeAverage8 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;
	my $rowchg;
	
	#print STDERR &Triceps::aggOpString($aggop), " ", &Triceps::opcodeString($opcode), " ", (!$rh->isNull()? $rh->getRow()->printP(): "NULL"), "\n";
	if ($aggop == &Triceps::AO_COLLAPSE) { 
		return
	} elsif ($aggop == &Triceps::AO_AFTER_DELETE) { 
		$state->{price_sum} -= $rh->getRow()->get("price");
	} elsif ($aggop == &Triceps::AO_AFTER_INSERT) { 
		$state->{price_sum} += $rh->getRow()->get("price");
	}
	# on AO_BEFORE_MOD do nothing

	return if ($context->groupSize()==0
		|| $opcode == &Triceps::OP_NOP);

	my $rLast = $context->last()->getRow() or die "$!";
	my $count = $context->groupSize();

	$context->makeHashSend($opcode, 
		symbol => $rLast->get("symbol"), 
		id => $rLast->get("id"), 
		price => $state->{price_sum}/$count,
	) or die "$!";
}

sub initAverage8 #  (@args)
{
	return { price_sum => 0 };
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
				$rtAvgPrice, "aggrAvgPrice", \&initAverage8, \&computeAverage8)
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

}; # SimpleAdditiveNoLast

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
&doSimpleAdditiveNoLast();
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
# the aggregator that just prints the call information

sub doPrintCall {

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
sub computeAverage9 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;
	
	#print STDERR &Triceps::aggOpString($aggop), " ", &Triceps::opcodeString($opcode), " ", $context->groupSize(), " ", (!$rh->isNull()? $rh->getRow()->printP(): "NULL"), "\n";
	&send(&Triceps::aggOpString($aggop), " ", &Triceps::opcodeString($opcode), " ", $context->groupSize(), " ", (!$rh->isNull()? $rh->getRow()->printP(): "NULL"), "\n");
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
				$rtAvgPrice, "aggrAvgPrice", undef, \&computeAverage9)
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

}; # PrintCall

#########################
#  run the same input as with manual aggregation

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_INSERT,3,BBB,20,20\n",
	"OP_DELETE,5\n",
);
$result = undef;
&doPrintCall();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
AO_AFTER_INSERT OP_INSERT 1 id="1" symbol="AAA" price="10" size="10" 
OP_INSERT,2,BBB,100,100
AO_AFTER_INSERT OP_INSERT 1 id="2" symbol="BBB" price="100" size="100" 
OP_INSERT,3,AAA,20,20
AO_BEFORE_MOD OP_DELETE 1 NULL
AO_AFTER_INSERT OP_INSERT 2 id="3" symbol="AAA" price="20" size="20" 
OP_INSERT,5,AAA,30,30
AO_BEFORE_MOD OP_DELETE 2 NULL
AO_AFTER_DELETE OP_NOP 2 id="1" symbol="AAA" price="10" size="10" 
AO_AFTER_INSERT OP_INSERT 2 id="5" symbol="AAA" price="30" size="30" 
OP_INSERT,3,BBB,20,20
AO_BEFORE_MOD OP_DELETE 2 NULL
AO_BEFORE_MOD OP_DELETE 1 NULL
AO_AFTER_DELETE OP_INSERT 1 id="3" symbol="AAA" price="20" size="20" 
AO_AFTER_INSERT OP_INSERT 2 id="3" symbol="BBB" price="20" size="20" 
OP_DELETE,5
AO_BEFORE_MOD OP_DELETE 1 NULL
AO_AFTER_DELETE OP_INSERT 0 id="5" symbol="AAA" price="30" size="30" 
AO_COLLAPSE OP_NOP 0 NULL
');

#########################
# the window with a non-additive aggregator and limit of 3,
# for a contrast to the ordered sum

sub doNonAdditive3 {

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
sub computeAverage10 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode != &Triceps::OP_INSERT);

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
		->addSubIndex("last4",
			Triceps::IndexType->newFifo(limit => 4)
			->setAggregator(Triceps::AggregatorType->new(
				$rtAvgPrice, "aggrAvgPrice", undef, \&computeAverage10)
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
		&send(sprintf("%.17g\n", $_[1]->getRow()->get("price")));
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

}; # NonAdditive3

#########################
# the sum done in proper floating-point order

sub doOrderedSum {

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

our $idxByPrice;

# aggregation handler: recalculate the average each time the easy way
sub computeAverage11 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;
	our $idxByPrice;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode != &Triceps::OP_INSERT);

	my $sum = 0;
	my $count = 0;
	my $end = $context->endIdx($idxByPrice);
	for (my $rhi = $context->beginIdx($idxByPrice); !$rhi->same($end); 
			$rhi = $rhi->nextIdx($idxByPrice)) {
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
		->addSubIndex("last4",
			Triceps::IndexType->newFifo(limit => 4)
			->setAggregator(Triceps::AggregatorType->new(
				$rtAvgPrice, "aggrAvgPrice", undef, \&computeAverage11)
			)
		)
		->addSubIndex("byPrice",
			Triceps::SimpleOrderedIndex->new(price => "ASC",)
			->addSubIndex("multi", Triceps::IndexType->newFifo())
		)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

$idxByPrice = $ttWindow->findSubIndex("bySymbol")
	->findSubIndex("byPrice") or die "$!";

# label to print the result of aggregation
my $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
	undef, sub { # (label, rowop)
		&send(sprintf("%.17g\n", $_[1]->getRow()->get("price")));
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

}; # OrderedSum

#########################
#  demonstrate the importance of order

@inputOrder = (
	"OP_INSERT,1,AAA,1,10\n",
	"OP_INSERT,2,AAA,1,10\n",
	"OP_INSERT,3,AAA,1,10\n",
	"OP_INSERT,4,AAA,1e16,10\n",
	"OP_INSERT,5,BBB,1e16,10\n",
	"OP_INSERT,6,BBB,1,10\n",
	"OP_INSERT,7,BBB,1,10\n",
	"OP_INSERT,8,BBB,1,10\n",
);

@input = @inputOrder;
$result = undef;
&doNonAdditive3();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,1,10
1
OP_INSERT,2,AAA,1,10
1
OP_INSERT,3,AAA,1,10
1
OP_INSERT,4,AAA,1e16,10
2500000000000001
OP_INSERT,5,BBB,1e16,10
10000000000000000
OP_INSERT,6,BBB,1,10
5000000000000000
OP_INSERT,7,BBB,1,10
3333333333333333.5
OP_INSERT,8,BBB,1,10
2500000000000000
');

@input = @inputOrder;
$result = undef;
&doOrderedSum();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,1,10
1
OP_INSERT,2,AAA,1,10
1
OP_INSERT,3,AAA,1,10
1
OP_INSERT,4,AAA,1e16,10
2500000000000001
OP_INSERT,5,BBB,1e16,10
10000000000000000
OP_INSERT,6,BBB,1,10
5000000000000000
OP_INSERT,7,BBB,1,10
3333333333333334
OP_INSERT,8,BBB,1,10
2500000000000001
');

#########################
# the sum done in proper floating-point order,
# now with the indexes swapped

sub doOrderedSum2 {

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

our $idxByOrder;

# aggregation handler: recalculate the average each time the easy way
sub computeAverage12 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;
	our $idxByOrder;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0
		|| $opcode != &Triceps::OP_INSERT);

	my $sum = 0;
	my $count = 0;
	for (my $rhi = $context->begin(); !$rhi->isNull(); 
			$rhi = $context->next($rhi)) {
		$count++;
		$sum += $rhi->getRow()->get("price");
	}
	my $rLast = $context->lastIdx($idxByOrder)->getRow() or die "$!";
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
		->addSubIndex("last4",
			Triceps::IndexType->newFifo(limit => 4)
		)
		->addSubIndex("byPrice",
			Triceps::SimpleOrderedIndex->new(price => "ASC",)
			->addSubIndex("multi", Triceps::IndexType->newFifo())
			->setAggregator(Triceps::AggregatorType->new(
				$rtAvgPrice, "aggrAvgPrice", undef, \&computeAverage12)
			)
		)
	)
or die "$!";
$ttWindow->initialize() or die "$!";
my $tWindow = $uTrades->makeTable($ttWindow, 
	&Triceps::EM_CALL, "tWindow") or die "$!";

$idxByOrder = $ttWindow->findSubIndex("bySymbol")
	->findSubIndex("last4") or die "$!";

# label to print the result of aggregation
my $lbAverage = $uTrades->makeLabel($rtAvgPrice, "lbAverage",
	undef, sub { # (label, rowop)
		&send(sprintf("%.17g\n", $_[1]->getRow()->get("price")));
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

}; # OrderedSum2

@input = @inputOrder;
$result = undef;
&doOrderedSum2();
#print $result;
ok($result, 
'OP_INSERT,1,AAA,1,10
1
OP_INSERT,2,AAA,1,10
1
OP_INSERT,3,AAA,1,10
1
OP_INSERT,4,AAA,1e16,10
2500000000000001
OP_INSERT,5,BBB,1e16,10
10000000000000000
OP_INSERT,6,BBB,1,10
5000000000000000
OP_INSERT,7,BBB,1,10
3333333333333334
OP_INSERT,8,BBB,1,10
2500000000000001
');

