#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Tests for the simple auto-generated aggregators.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;
use Carp;

use Test;
BEGIN { plan tests => 71 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;

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

# instantiate the table and run it with the given input
sub runExample($$$) # ($unit, $tabType, $aggName)
{
	my ($unit, $tt, $aggName) = @_;
	$tt->initialize() or confess "$!";
	my $t = $unit->makeTable($tt, &Triceps::EM_CALL, "t") or confess "$!";
	my $lbAgg = $t->getAggregatorLabel($aggName) or confess "$!";
	
	# label to print the result of aggregation
	my $lbPrint = $unit->makeLabel($lbAgg->getType(), "lbPrint",
		undef, sub { # (label, rowop)
			&send($_[1]->printP(), "\n");
		}) or confess "$!";

	$lbAgg->chain($lbPrint) or confess "$!";

	while(&readLine) {
		chomp;
		my @data = split(/,/); # starts with a string opcode
		$unit->makeArrayCall($t->getInputLabel(), @data);
		$unit->drainFrame(); # just in case, for completeness
	}
	# XXX this leaks labels $lbPrint until the unit gets cleared
	# (since forgetLabel() is not in Perl API at the moment)
}

# the input data
my $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or confess "$!";

# create a new table type for trades, to put an aggregator on

sub makeTtWindow
{
	return Triceps::TableType->new($rtTrade)
		->addSubIndex("byId", 
			Triceps::IndexType->newHashed(key => [ "id" ])
		)
		->addSubIndex("bySymbol", 
			Triceps::IndexType->newHashed(key => [ "symbol" ])
			->addSubIndex("last2",
				Triceps::IndexType->newFifo(limit => 2)
			)
		);
}

# extra functions for the test purposes
our $test_functions = {
	# test the overriding
	sum => {
		vars => { sum => 0 },
		step => '$%sum += $%argiter;',
		result => '$%sum + 1000',
	},
	_defective => { # purely for test purposes, a defective definition
	},
	_defective_syntax => { # purely for test purposes, a defective definition
		result => 'XXXXXXX',
	},
	_defective_argiter => { # purely for test purposes, a defective definition
		argcount => 0,
		step => '$%argiter',
		result => '0',
	},
	_defective_stepvar => { # purely for test purposes, a defective definition
		argcount => 0,
		step => '$%x',
		result => '0',
	},
	_defective_argfirst => { # purely for test purposes, a defective definition
		argcount => 0,
		result => '$%argfirst',
	},
	_defective_arglast => { # purely for test purposes, a defective definition
		argcount => 0,
		result => '$%arglast',
	},
	_defective_resultvar => { # purely for test purposes, a defective definition
		argcount => 0,
		result => '$%x',
	},
	_defective_vars => {
		vars => 0,
	},
	_defective_vars_init => {
		vars => { sum => [ ] },
	},
	_defective_step => {
		step => { sum => 1 },
	},
	_defective_result => {
		result => { sum => 1 },
	},
};
#########################
# touch-test of all the main code-building paths

my $uTrades = Triceps::Unit->new("uTrades") or confess "$!";

my $ttWindow = &makeTtWindow or confess "$!";

my $compText = 1;
my $initText = 1;
my $rtAggr = 1;
my $res = Triceps::SimpleAggregator::make(
	tabType => $ttWindow,
	name => "myAggr",
	idxPath => [ "bySymbol", "last2" ],
	result => [
		symbol => "string", "first", sub {$_[0]->get("symbol");},
		id => "int32", "last", sub {$_[0]->get("id");},
		volume => "float64", "sum", sub {$_[0]->get("size");},
		count => "int32", "count_star", undef,
		second => "int32", "nth_simple", sub { [1, $_[0]->get("id")];},
	],
	saveRowTypeTo => \$rtAggr,
	saveComputeTo => \$compText,
	saveInitTo => \$initText,
);
ok(ref $res, "Triceps::TableType");
ok($ttWindow->same($res));
ok(ref $rtAggr, "Triceps::RowType");
ok($rtAggr->print(undef), "row { string symbol, int32 id, float64 volume, int32 count, int32 second, }");
#print $compText;
ok(!defined($initText));
# check that the code elements are present
ok($compText =~ /rhi = /);
ok($compText =~ /rowFirst = /);
ok($compText =~ /rowLast = /);

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_INSERT,3,BBB,20,20\n",
	"OP_DELETE,5\n",
);
$result = undef;
&runExample($uTrades, $ttWindow, "myAggr");
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
t.myAggr OP_INSERT symbol="AAA" id="1" volume="10" count="1" 
OP_INSERT,2,BBB,100,100
t.myAggr OP_INSERT symbol="BBB" id="2" volume="100" count="1" 
OP_INSERT,3,AAA,20,20
t.myAggr OP_DELETE symbol="AAA" id="1" volume="10" count="1" 
t.myAggr OP_INSERT symbol="AAA" id="3" volume="30" count="2" second="3" 
OP_INSERT,5,AAA,30,30
t.myAggr OP_DELETE symbol="AAA" id="3" volume="30" count="2" second="3" 
t.myAggr OP_INSERT symbol="AAA" id="5" volume="50" count="2" second="5" 
OP_INSERT,3,BBB,20,20
t.myAggr OP_DELETE symbol="AAA" id="5" volume="50" count="2" second="5" 
t.myAggr OP_DELETE symbol="BBB" id="2" volume="100" count="1" 
t.myAggr OP_INSERT symbol="AAA" id="5" volume="30" count="1" 
t.myAggr OP_INSERT symbol="BBB" id="3" volume="120" count="2" second="3" 
OP_DELETE,5
t.myAggr OP_DELETE symbol="AAA" id="5" volume="30" count="1" 
');

#########################
# test of path for the count only

$ttWindow = &makeTtWindow or confess "$!";

undef $compText;
undef $rtAggr;
$res = Triceps::SimpleAggregator::make(
	tabType => $ttWindow,
	name => "myAggr",
	idxPath => [ "bySymbol", "last2" ],
	result => [
		count => "int32", "count_star", undef,
	],
	saveRowTypeTo => \$rtAggr,
	saveComputeTo => \$compText,
);
ok(ref $res, "Triceps::TableType");
ok($ttWindow->same($res));
ok(ref $rtAggr, "Triceps::RowType");
ok($rtAggr->print(undef), "row { int32 count, }");
#print $compText;
# check that the code elements are present or absent
ok($compText !~ /rhi = /);
ok($compText !~ /rowFirst = /);
ok($compText !~ /rowLast = /);

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_INSERT,3,BBB,20,20\n",
	"OP_DELETE,5\n",
);
$result = undef;
&runExample($uTrades, $ttWindow, "myAggr");
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
t.myAggr OP_INSERT count="1" 
OP_INSERT,2,BBB,100,100
t.myAggr OP_INSERT count="1" 
OP_INSERT,3,AAA,20,20
t.myAggr OP_DELETE count="1" 
t.myAggr OP_INSERT count="2" 
OP_INSERT,5,AAA,30,30
t.myAggr OP_DELETE count="2" 
t.myAggr OP_INSERT count="2" 
OP_INSERT,3,BBB,20,20
t.myAggr OP_DELETE count="2" 
t.myAggr OP_DELETE count="1" 
t.myAggr OP_INSERT count="1" 
t.myAggr OP_INSERT count="2" 
OP_DELETE,5
t.myAggr OP_DELETE count="1" 
');

#########################
# test of path for the first only

$ttWindow = &makeTtWindow or confess "$!";

undef $compText;
undef $rtAggr;
$res = Triceps::SimpleAggregator::make(
	tabType => $ttWindow,
	name => "myAggr",
	idxPath => [ "bySymbol", "last2" ],
	result => [
		symbol => "string", "first", sub {$_[0]->get("symbol");},
	],
	saveRowTypeTo => \$rtAggr,
	saveComputeTo => \$compText,
);
ok(ref $res, "Triceps::TableType");
ok($ttWindow->same($res));
ok(ref $rtAggr, "Triceps::RowType");
ok($rtAggr->print(undef), "row { string symbol, }");
#print $compText;
# check that the code elements are present or absent
ok($compText !~ /rhi = /);
ok($compText =~ /rowFirst = /);
ok($compText !~ /rowLast = /);

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_INSERT,3,BBB,20,20\n",
	"OP_DELETE,5\n",
);
$result = undef;
&runExample($uTrades, $ttWindow, "myAggr");
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
t.myAggr OP_INSERT symbol="AAA" 
OP_INSERT,2,BBB,100,100
t.myAggr OP_INSERT symbol="BBB" 
OP_INSERT,3,AAA,20,20
t.myAggr OP_DELETE symbol="AAA" 
t.myAggr OP_INSERT symbol="AAA" 
OP_INSERT,5,AAA,30,30
t.myAggr OP_DELETE symbol="AAA" 
t.myAggr OP_INSERT symbol="AAA" 
OP_INSERT,3,BBB,20,20
t.myAggr OP_DELETE symbol="AAA" 
t.myAggr OP_DELETE symbol="BBB" 
t.myAggr OP_INSERT symbol="AAA" 
t.myAggr OP_INSERT symbol="BBB" 
OP_DELETE,5
t.myAggr OP_DELETE symbol="AAA" 
');

#########################
# test of path for the last only

$ttWindow = &makeTtWindow or confess "$!";

undef $compText;
undef $rtAggr;
$res = Triceps::SimpleAggregator::make(
	tabType => $ttWindow,
	name => "myAggr",
	idxPath => [ "bySymbol", "last2" ],
	result => [
		symbol => "string", "last", sub {$_[0]->get("symbol");},
	],
	saveRowTypeTo => \$rtAggr,
	saveComputeTo => \$compText,
);
ok(ref $res, "Triceps::TableType");
ok($ttWindow->same($res));
ok(ref $rtAggr, "Triceps::RowType");
ok($rtAggr->print(undef), "row { string symbol, }");
#print $compText;
# check that the code elements are present or absent
ok($compText !~ /rhi = /);
ok($compText !~ /rowFirst = /);
ok($compText =~ /rowLast = /);

@input = (
	"OP_INSERT,1,AAA,10,10\n",
	"OP_INSERT,2,BBB,100,100\n",
	"OP_INSERT,3,AAA,20,20\n",
	"OP_INSERT,5,AAA,30,30\n",
	"OP_INSERT,3,BBB,20,20\n",
	"OP_DELETE,5\n",
);
$result = undef;
&runExample($uTrades, $ttWindow, "myAggr");
#print $result;
ok($result, 
'OP_INSERT,1,AAA,10,10
t.myAggr OP_INSERT symbol="AAA" 
OP_INSERT,2,BBB,100,100
t.myAggr OP_INSERT symbol="BBB" 
OP_INSERT,3,AAA,20,20
t.myAggr OP_DELETE symbol="AAA" 
t.myAggr OP_INSERT symbol="AAA" 
OP_INSERT,5,AAA,30,30
t.myAggr OP_DELETE symbol="AAA" 
t.myAggr OP_INSERT symbol="AAA" 
OP_INSERT,3,BBB,20,20
t.myAggr OP_DELETE symbol="AAA" 
t.myAggr OP_DELETE symbol="BBB" 
t.myAggr OP_INSERT symbol="AAA" 
t.myAggr OP_INSERT symbol="BBB" 
OP_DELETE,5
t.myAggr OP_DELETE symbol="AAA" 
');

#########################
# test without optional options

$ttWindow = &makeTtWindow or confess "$!";

$res = Triceps::SimpleAggregator::make(
	tabType => $ttWindow,
	name => "myAggr",
	idxPath => [ "bySymbol", "last2" ],
	result => [
		symbol => "string", "last", sub {$_[0]->get("symbol");},
	],
);
ok(ref $res, "Triceps::TableType");

#########################
# errors: missing mandatory options

$ttWindow = &makeTtWindow or confess "$!";
$res = eval {
	Triceps::SimpleAggregator::make(
		name => "myAggr",
		idxPath => [ "bySymbol", "last2" ],
		result => [
			symbol => "string", "last", sub {$_[0]->get("symbol");},
		],
	);
}; 
ok($@ =~ /^Option 'tabType' must be specified for class 'Triceps::SimpleAggregator'/);

$ttWindow = &makeTtWindow or confess "$!";
$res = eval {
	Triceps::SimpleAggregator::make(
		tabType => $ttWindow,
		idxPath => [ "bySymbol", "last2" ],
		result => [
			symbol => "string", "last", sub {$_[0]->get("symbol");},
		],
	);
};
ok($@ =~ /^Option 'name' must be specified for class 'Triceps::SimpleAggregator'/);

$ttWindow = &makeTtWindow or confess "$!";
$res = eval {
	Triceps::SimpleAggregator::make(
		tabType => $ttWindow,
		name => "myAggr",
		result => [
			symbol => "string", "last", sub {$_[0]->get("symbol");},
		],
	);
};
ok($@ =~ /^Option 'idxPath' must be specified for class 'Triceps::SimpleAggregator'/);

$ttWindow = &makeTtWindow or confess "$!";
$res = eval {
	Triceps::SimpleAggregator::make(
		tabType => $ttWindow,
		name => "myAggr",
		idxPath => [ "bySymbol", "last2" ],
	);
};
ok($@ =~ /^Option 'result' must be specified for class 'Triceps::SimpleAggregator'/);

#########################
# errors: bad values in options

sub tryBadOptValue($$) # (optName, optValue)
{
	$ttWindow = &makeTtWindow or confess "$!";
	my %opts = (
		tabType => $ttWindow,
		name => "myAggr",
		idxPath => [ "bySymbol", "last2" ],
		result => [
			symbol => "string", "last", sub {$_[0]->get("symbol");},
		],
		saveRowTypeTo => \$rtAggr,
		saveComputeTo => \$compText,
		saveInitTo => \$initText,
		functions => $test_functions,
	);
	$opts{$_[0]} = $_[1];
	$res = eval {
		Triceps::SimpleAggregator::make(%opts);
	};
}

tryBadOptValue(
		tabType => "zzz",
);
ok($@ =~ /^Option 'tabType' of class 'Triceps::SimpleAggregator' must be a reference to 'Triceps::TableType', is/);

tryBadOptValue(
		idxPath => { "bySymbol", "last2" },
);
ok($@ =~ /^Option 'idxPath' of class 'Triceps::SimpleAggregator' must be a reference to 'ARRAY', is/);

tryBadOptValue(
		idxPath => [ $ttWindow ],
);
ok($@ =~ /^Option 'idxPath' of class 'Triceps::SimpleAggregator' must be a reference to 'ARRAY' '', is/);

tryBadOptValue(
		result => { }
);
ok($@ =~ /^Option 'result' of class 'Triceps::SimpleAggregator' must be a reference to 'ARRAY', is/);

tryBadOptValue(
		idxPath => [ ],
);
ok($@ =~ /^Triceps::TableType::findIndexPath: idxPath must be an array of non-zero length/);

tryBadOptValue(
		idxPath => [ "bySymbol", "zzz" ],
);
ok($@ =~ /^Triceps::TableType::findIndexPath: unable to find the index type at path 'bySymbol.zzz'/);

$ttWindow = &makeTtWindow or confess "$!";
$ttWindow->initialize();
$res = eval {
	Triceps::SimpleAggregator::make(
		tabType => $ttWindow,
		name => "myAggr",
		idxPath => [ "bySymbol", "last2" ],
		result => [
			symbol => "string", "last", sub {$_[0]->get("symbol");},
		],
	);
};
ok($@ =~ /^Triceps::SimpleAggregator::make: the index type is already initialized, can not add an aggregator on it/);

tryBadOptValue(
		result => [
			symbol => "string", "last", sub {$_[0]->get("symbol");},
			id => "int32", "last",
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: the values in the result definition must go in groups of 4/);

tryBadOptValue(
		result => [
			symbol => "string", "last", sub {$_[0]->get("symbol");}, sub {$_[0]->get("symbol");},
			id => "int32", "last", sub {$_[0]->get("id");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: the result field name must be a string, got a CODE/);

tryBadOptValue(
		result => [
			symbol => sub {$_[0]->get("symbol");},
			id => "int32", "last", sub {$_[0]->get("id");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: the result field type must be a string, got a CODE for field 'symbol'/);

tryBadOptValue(
		result => [
			symbol => "string", sub {$_[0]->get("symbol");},
			id => "int32", "last", sub {$_[0]->get("id");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: the result field function must be a string, got a CODE for field 'symbol'/);

tryBadOptValue(
		result => [
			symbol => "string", "nosuch", sub {$_[0]->get("symbol");},
			id => "int32", "last", sub {$_[0]->get("id");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: function 'nosuch' is unknown/);

tryBadOptValue(
		result => [
			symbol => "string", "first", 
			id => "int32", "last", sub {$_[0]->get("id");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: in field 'symbol' function 'first' requires an argument computation that must be a Perl sub reference/);

tryBadOptValue(
		result => [
			symbol => "string", "count_star", sub {$_[0]->get("symbol");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: in field 'symbol' function 'count_star' requires no argument, use undef as a placeholder/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective", sub {$_[0]->get("symbol");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective', missing result computation/);

tryBadOptValue(
		result => [
			symbol => "string[]", "last", sub {$_[0]->get("symbol");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: invalid result row type definition: Triceps::RowType::new: field 'symbol' string array type is not supported/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_syntax", sub {$_[0]->get("symbol");},
		],
);
ok($@ =~ /^Triceps::SimpleAggregator::make: error in compilation of the aggregation computation:/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_argiter", undef
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_argiter', step computation refers to 'argiter' but the function declares no arguments/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_argfirst", undef
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_argfirst', result computation refers to 'argfirst' but the function declares no arguments/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_arglast", undef
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_arglast', result computation refers to 'arglast' but the function declares no arguments/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_stepvar", undef
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_stepvar', step computation refers to an unknown variable 'x'/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_resultvar", undef
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_resultvar', result computation refers to an unknown variable 'x'/);

tryBadOptValue(
		functions => { a => 10 }
);
ok($@ =~ /^Option 'functions' of class 'Triceps::SimpleAggregator' must be a reference to 'HASH' 'HASH', is 'HASH' ''/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_vars", sub { 0; }
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_vars', vars element must be a 'HASH' reference/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_vars_init", sub { 0; }
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_vars_init', vars initialization value for 'sum' must be a string/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_step", sub { 0; }
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_step', step value must be a string/);

tryBadOptValue(
		result => [
			symbol => "string", "_defective_result", sub { 0; }
		],
);
ok($@ =~ /^Triceps::SimpleAggregator: internal error in definition of aggregation function '_defective_result', result value must be a string/);
#print "$@\n";

#########################
# test the aggregation functions that weren't exercised in the first example
$ttWindow = &makeTtWindow or confess "$!";

undef $compText;
undef $rtAggr;
$res = Triceps::SimpleAggregator::make(
	tabType => $ttWindow,
	name => "myAggr",
	idxPath => [ "bySymbol", "last2" ],
	result => [
		symbol => "string", "first", sub {$_[0]->get("symbol");},
		id => "int32", "first", sub {$_[0]->get("id");},
		maxsize => "float64", "max", sub {$_[0]->get("size");},
		minsize => "float64", "min", sub {$_[0]->get("size");},
		count => "int32", "count", sub {$_[0]->get("size");},
		avg => "float64", "avg", sub {$_[0]->get("size");},
		# the following makes the Perl test warnings shut up on NULL fields
		avgperl => "float64", "avg_perl", sub { my $x = $_[0]->get("size"); if (!defined $x) {$x = 0;}; return $x},
		xsum => "float64", "sum", sub { my $x = $_[0]->get("size"); if (!defined $x) {$x = 0;}; return $x},
	],
	saveRowTypeTo => \$rtAggr,
	saveComputeTo => \$compText,
	saveInitTo => \$initText,
	functions => $test_functions,
);
ok(ref $res, "Triceps::TableType");
ok($ttWindow->same($res));
ok(ref $rtAggr, "Triceps::RowType");
ok($rtAggr->print(undef), "row { string symbol, int32 id, float64 maxsize, float64 minsize, int32 count, float64 avg, float64 avgperl, float64 xsum, }");
#print $compText;

@input = (
	"OP_INSERT,1,AAA,10,\n",
	"OP_INSERT,2,AAA,10,100\n",
	"OP_INSERT,3,AAA,10,200\n",
	"OP_INSERT,4,AAA,10,50\n",
);
$result = undef;
&runExample($uTrades, $ttWindow, "myAggr");
#print $result;
# the old records get pushed out of the window by the limit
ok($result, 
'OP_INSERT,1,AAA,10,
t.myAggr OP_INSERT symbol="AAA" id="1" count="0" avgperl="0" xsum="1000" 
OP_INSERT,2,AAA,10,100
t.myAggr OP_DELETE symbol="AAA" id="1" count="0" avgperl="0" xsum="1000" 
t.myAggr OP_INSERT symbol="AAA" id="1" maxsize="100" minsize="100" count="1" avg="100" avgperl="50" xsum="1100" 
OP_INSERT,3,AAA,10,200
t.myAggr OP_DELETE symbol="AAA" id="1" maxsize="100" minsize="100" count="1" avg="100" avgperl="50" xsum="1100" 
t.myAggr OP_INSERT symbol="AAA" id="2" maxsize="200" minsize="100" count="2" avg="150" avgperl="150" xsum="1300" 
OP_INSERT,4,AAA,10,50
t.myAggr OP_DELETE symbol="AAA" id="2" maxsize="200" minsize="100" count="2" avg="150" avgperl="150" xsum="1300" 
t.myAggr OP_INSERT symbol="AAA" id="3" maxsize="200" minsize="50" count="2" avg="125" avgperl="125" xsum="1250" 
');
