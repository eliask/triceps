#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# An application example of VWAP calculation.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 19 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

######################### types will be used in all versions #############

# incoming data: symbol trade information
@defTrade = (
	symbol => "string",
	volume => "float64",
	price => "float64",
);
$rtTrade = Triceps::RowType->new(
	@defTrade
);
ok(ref $rtTrade, "Triceps::RowType");

# outgoing data: symbol's summary for the day
@defVwap = (
	symbol => "string",
	volume => "float64",
	vwap => "float64",
);
$rtVwap = Triceps::RowType->new(
	@defVwap
);
ok(ref $rtVwap, "Triceps::RowType");

# label handler to collect the output
@resultData = ();
sub collectOutput # (label, rowop)
{
	my ($label, $rowop) = @_;
	if ($rowop->getOpcode() == &Triceps::OP_INSERT) {
		push @resultData, [ $rowop->getRow()->toArray() ];
	}
}

########## input and expected output data for all the versions ################

@inputData = (
	[ "abc", 100, 123 ],
	[ "abc", 300, 125 ],
	[ "def", 100, 200 ],
	[ "fgh", 100, 1000 ],
	[ "abc", 300, 128 ],
	[ "fgh", 25, 1100 ],
	[ "def", 100, 202 ],
	[ "def", 1000, 192 ],
);

# result: symbol, volume today, vwap today
@expectResultData = (
	[ "abc", 100, 123 ],
	[ "abc", 400, 124.5 ],
	[ "def", 100, 200 ],
	[ "fgh", 100, 1000 ],
	[ "abc", 700, 126 ],
	[ "fgh", 125, 1020 ],
	[ "def", 200, 201 ],
	[ "def", 1200, 193.5 ],
);

############################# helper functions ###########################

# helper function to feed the input data to a label
sub feedInput # (unit, label)
{
	my ($unit, $label) = @_;
	foreach my $tuple (@inputData) {
		# print STDERR "feed [" . join(", ", @$tuple) . "]\n";
		my $rowop = $label->makeRowop(&Triceps::OP_INSERT, $rtTrade->makeRowArray(@$tuple));
		$unit->schedule($rowop);
	}
}

# convert a data set to a string
sub dataToString # (@dataSet)
{
	my $res;
	foreach my $tuple (@_) {
		$res .= "(" . join(", ", @$tuple) . ")\n";
	}
	return $res;
}

###################### 1. hardcoded VWAP #################################

# XXX this is too difficult to do manually every time, should be a better way...

$vu1 = Triceps::Unit->new("vu1");
ok(ref $vu1, "Triceps::Unit");

# aggregation handler: recalculate it each time the easy way
sub vwapHandler1 # (table, context, aggop, opcode, rh, state, args...)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, @args) = @_;

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0 # AO_COLLAPSE really gets taken care of here
		|| $opcode == &Triceps::OP_NOP); # skip the ignored intermediate updates

	my $firstRow = $context->begin()->getRow();
	my $volume = 0;
	my $cost = 0;
	for (my $iterh = $context->begin(); !$iterh->isNull(); $iterh = $context->next($iterh)) {
		my $tvol = $iterh->getRow()->get("volume");
		$volume += $tvol;
		$cost += $tvol * $iterh->getRow()->get("price");
	}

	my $res = $context->resultType()->makeRowArray($firstRow->get("symbol"), $volume,
		($volume == 0 ? 0 : $cost/$volume) );
	$context->send($opcode, $res);
}

$agtVwap1 = Triceps::AggregatorType->new($rtVwap, "aggrVwap", undef, \&vwapHandler1);
ok(ref $agtVwap1, "Triceps::AggregatorType");

# index the incoming trades by symbol, and keep all trades for aggregation in FIFO
$itTradeDepth1 = Triceps::IndexType->newHashed(key => [ "symbol" ])
	->addSubIndex("fifo", Triceps::IndexType->newFifo()
		->setAggregator($agtVwap1)
	);
ok(ref $itTradeDepth1, "Triceps::IndexType");

# the table for aggregation
$ttAggr1 = Triceps::TableType->new($rtTrade)
	->addSubIndex("grouping", $itTradeDepth1 ); 
ok(ref $ttAggr1, "Triceps::TableType");

$res = $ttAggr1->initialize();
ok($res, 1);

$tAggr1 = $vu1->makeTable($ttAggr1, &Triceps::EM_FORK, "tAggr1");
ok(ref $tAggr1, "Triceps::Table");

# the label that processes the results of aggregation
$resLabel1 = $vu1->makeLabel($rtVwap, "collect", undef, \&collectOutput);
ok(ref $resLabel1, "Triceps::Label");
ok($tAggr1->getAggregatorLabel("aggrVwap")->chain($resLabel1));

# now reset the output and feed the input
@resultData = ();
&feedInput($vu1, $tAggr1->getInputLabel());
$vu1->drainFrame();
ok($vu1->empty());

# compare the result
ok(&dataToString(@resultData), &dataToString(@expectResultData));

###################### 2. Sub-element calculating VWAP #################################

############################# vwap package ####################################
# XXX it's not good at error checking... something needs to be done...
package vwap2;

# aggregation handler: recalculate it each time the easy way
sub vwapHandler # (table, context, aggop, opcode, rh, state, self)
{
	my ($table, $context, $aggop, $opcode, $rh, $state, $self) = @_;

	if (!$rh->isNull()) {
		# print STDERR "agg row [" . join(", ", $rh->getRow()->toHash()) . "]\n";
	} else {
		# print STDERR "agg NULL\n";
	}

	# don't send the NULL record after the group becomes empty
	return if ($context->groupSize()==0 # AO_COLLAPSE really gets taken care of here
		|| $opcode == &Triceps::OP_NOP); # skip the ignored intermediate updates

	my $firstRow = $context->begin()->getRow();
	my $volume = 0;
	my $cost = 0;
	for (my $iterh = $context->begin(); !$iterh->isNull(); $iterh = $context->next($iterh)) {
		my $tvol = $iterh->getRow()->get($self->{volumeFld});
		$volume += $tvol;
		$cost += $tvol * $iterh->getRow()->get($self->{priceFld});
	}

	# most of fields come through as last()
	my $lastrh = $context->last();
	my %data = $lastrh->getRow()->toHash();

	# a production version should have an option for what to remove but
	# for a demo the hardcoded "always replace price and volume" is good enough

	# delete the price field
	delete $data{$self->{priceFld}};
	# add the vwap field
	$data{$self->{vwapFld}} = ($volume == 0 ? 0 : $cost/$volume);
	# replace the volume field
	$data{$self->{volumeFld}} = $volume;

	# print STDERR "made [" . join(", ", %data) . "]\n";
	my $res = $context->resultType()->makeRowHash(%data);
	$context->send($opcode, $res);
}

# A generic function to drop certain fields from
# row type definition, XXX should move to the Triceps library.
#  @param what - reference to array of fields to drop
#  @param (fldName, fldType)... - definition of fields for row type
#  @return - definitions (fldName, fldType)... with dropped fields 
sub dropFields # (@$what, $fldName, $fldType...)
{
	my $what = shift;
	my (%keys, $k, $v, @res);
	foreach $k (@$what) {
		$keys{$k} = 1;
	}
	while ($#_ >= 1) {
		$k = shift;
		$v = shift;
		if (!exists $keys{$k}) {
			push @res, $k, $v;
		}
	}
	return @res;
}

sub new # (class, optionName => optionValue ...)
{
	my $class = shift;
	my $self = {};

	# XXX add type checks for arguments
	&Triceps::Opt::parse($class, $self, {
			unit => [ undef, \&Triceps::Opt::ck_mandatory ],
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			rowType => [ undef, \&Triceps::Opt::ck_mandatory ],
			key => [ undef, \&Triceps::Opt::ck_mandatory ],
			volumeFld => [ undef, \&Triceps::Opt::ck_mandatory ],
			priceFld => [ undef, \&Triceps::Opt::ck_mandatory ],
			vwapFld => [ undef, \&Triceps::Opt::ck_mandatory ],
			enqMode => [ undef, \&Triceps::Opt::ck_mandatory ],
		}, @_);

	# build the output row type
	my @fields = &dropFields([$self->{priceFld}], $self->{rowType}->getdef());
	push @fields, $self->{vwapFld}, "float64";
	my $ort = Triceps::RowType->new(@fields);
	$self->{outputRowType} = $ort;

	# build the aggregation table
	my $agtype = Triceps::AggregatorType->new($ort, "aggrVwap", undef, \&vwapHandler, $self);
	my $tabtype = Triceps::TableType->new($self->{rowType})
		->addSubIndex("primary", Triceps::IndexType->newHashed(key => $self->{key})
			->addSubIndex("fifo", Triceps::IndexType->newFifo()
				->setAggregator($agtype)
			)
		);
	$tabtype->initialize() or Carp::confess "Failed to initialize the VWAP table type: $!";
	$self->{tabType} = $tabtype;
	my $t = $self->{unit}->makeTable($tabtype, $self->{enqMode}, $self->{name} . ".agg");
	Carp::confess "Failed to create the VWAP table: $!" unless (ref $t eq "Triceps::Table");
	$self->{table} = $t;

	bless $self, $class;
	return $self;
}

sub getInputLabel # (self)
{
	my $self = shift;
	return $self->{table}->getInputLabel();
}

sub getOutputLabel # (self)
{
	my $self = shift;
	return $self->{table}->getAggregatorLabel("aggrVwap");
}

sub getInputRowType # (self)
{
	my $self = shift;
	return $self->{rowType};
}

sub getOutputRowType # (self)
{
	my $self = shift;
	return $self->{outputRowType};
}

package main;
######################## instantiate and run ########################

$vu2 = Triceps::Unit->new("vu2");
ok(ref $vu2, "Triceps::Unit");

my $vwapper2 = vwap2->new(
			unit => $vu2,
			name => "vwapper",
			rowType => $rtTrade,
			key => [ "symbol" ],
			volumeFld => "volume",
			priceFld => "price",
			vwapFld => "vwap",
			enqMode => &Triceps::EM_FORK,
);
ok(ref $vwapper2, "vwap2");

# the label that processes the results of aggregation
$resLabel2 = $vu2->makeLabel($vwapper2->getOutputRowType(), "collect", undef, \&collectOutput);
ok(ref $resLabel2, "Triceps::Label");
ok($vwapper2->getOutputLabel()->chain($resLabel2));

# now reset the output and feed the input
@resultData = ();
&feedInput($vu2, $vwapper2->getInputLabel());
$vu2->drainFrame();
ok($vu2->empty());

# compare the result
ok(&dataToString(@resultData), &dataToString(@expectResultData));

# XXX properly should also test the error handling in vwap2, which isn't good at the moment
