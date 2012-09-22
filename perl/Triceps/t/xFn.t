#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Exzmples with the streaming functions.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 5 };
use Triceps;
use Carp;
ok(1); # If we made it this far, we're ok.

use strict;

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
	$result .= "> $_" if defined $_; # have the inputs overlap in result, as on screen
	return $_;
}

# write a message to user
sub send # (@message)
{
	$result .= join('', @_);
}

# write a message to user, like printf
sub sendf # ($msg, $vars...)
{
	my $fmt = shift;
	$result .= sprintf($fmt, @_);
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

# a template to make a label that prints the data passing through another label
sub makePrintLabel($$) # ($print_label_name, $parent_label)
{
	my $name = shift;
	my $lbParent = shift;
	my $lb = $lbParent->getUnit()->makeLabel($lbParent->getType(), $name,
		undef, sub { # (label, rowop)
			&send($_[1]->printP(), "\n");
		}) or confess "$!";
	$lbParent->chain($lb) or confess "$!";
	return $lb;
}

############################################################
# A looping Fibonacci computation with the streaming functions.

sub doFibFn1 {
# compute some Fibonacci numbers in a perverse way

my $uFib = Triceps::Unit->new("uFib") or confess "$!";

###
# A streaming function that computes one step of a
# Fibonacci number, will be called repeatedly.

# Type of its input and output.
my $rtFib = Triceps::RowType->new(
	iter => "int32", # number of iterations left to do
	cur => "int64", # current number
	prev => "int64", # previous number
) or confess "$!";

# Input: 
#   $lbFibCompute: request to do a step. iter will be decremented,
#     cur moved to prev, new value of cur computed.
# Output (by FnReturn labels):
#   "next": data to send to the next step, if the iteration
#     is not finished yet (iter in the produced row is >0).
#   "result": the result data if the iretaion is finished
#     (iter in the produced row is 0).
# The opcode is preserved through the computation.

my $frFib = Triceps::FnReturn->new(
	name => "Fib",
	unit => $uFib,
	labels => [
		next => $rtFib,
		result => $rtFib,
	],
);

my $lbFibCompute = $uFib->makeLabel($rtFib, "FibCompute", undef, sub {
	my $row = $_[1]->getRow();
	my $prev = $row->get("cur");
	my $cur = $prev + $row->get("prev");
	my $iter = $row->get("iter") - 1;
	$uFib->makeHashCall($frFib->getLabel($iter > 0? "next" : "result"), $_[1]->getOpcode(),
		iter => $iter,
		cur => $cur,
		prev => $prev,
	);
}) or confess "$!";

# End of streaming function
###

my $lbPrint = $uFib->makeLabel($rtFib, "Print", undef, sub {
	&send($_[1]->getRow()->get("cur"));
});

# binding to run the Triceps steps in a loop
my $fbFibLoop = Triceps::FnBinding->new(
	name => "FibLoop",
	on => $frFib,
	withTray => 1,
	labels => [
		next => $lbFibCompute,
		result => $lbPrint,
	],
);

my $lbMain = $uFib->makeLabel($rtFib, "Main", undef, sub {
	my $row = $_[1]->getRow();
	{
		my $ab = Triceps::AutoFnBind->new($frFib, $fbFibLoop);

		# send the request into the loop
		$uFib->makeHashCall($lbFibCompute, $_[1]->getOpcode(),
			iter => $row->get("iter"),
			cur => 0, # the "0-th" number
			prev => 1,
		);

		# now keep cycling the loop until it's all done
		while (!$fbFibLoop->trayEmpty()) {
			$fbFibLoop->callTray();
		}
	}
	&send(" is Fibonacci number ", $row->get("iter"), "\n");
}) or confess "$!";

while(&readLine) {
	chomp;
	my @data = split(/,/);
	$uFib->makeArrayCall($lbMain, @data);
	$uFib->drainFrame(); # just in case, for completeness
}

} # doFibFn1

@input = (
	"OP_INSERT,1\n",
	"OP_DELETE,2\n",
	"OP_INSERT,5\n",
	"OP_INSERT,6\n",
);
$result = undef;
&doFibFn1();
#print $result;
ok($result, 
'> OP_INSERT,1
1 is Fibonacci number 1
> OP_DELETE,2
1 is Fibonacci number 2
> OP_INSERT,5
5 is Fibonacci number 5
> OP_INSERT,6
8 is Fibonacci number 6
');

############################################################
# A looping Fibonacci computation with the streaming functions
# and the final output going directly to $lbPrint, without binding.

sub doFibFn2 {
# compute some Fibonacci numbers in a perverse way

my $uFib = Triceps::Unit->new("uFib") or confess "$!";

# Type the data going through the loop.
my $rtFib = Triceps::RowType->new(
	iter => "int32", # number of iterations left to do
	cur => "int64", # current number
	prev => "int64", # previous number
) or confess "$!";

my $lbPrint = $uFib->makeLabel($rtFib, "Print", undef, sub {
	&send($_[1]->getRow()->get("cur"));
});

###
# A streaming function that computes one step of a
# Fibonacci number, will be called repeatedly.

# Input: 
#   $lbFibCompute: request to do a step. iter will be decremented,
#     cur moved to prev, new value of cur computed.
# Looping Output (by FnReturn labels):
#   "next": data to send to the next step, if the iteration
#     is not finished yet (iter in the produced row is >0).
# Output connections:
#   Sent to $lbPrint: the result data if the iretaion is finished
#     (iter in the produced row is 0).
# The opcode is preserved through the computation.

my $frFib = Triceps::FnReturn->new(
	name => "Fib",
	unit => $uFib,
	labels => [
		next => $rtFib,
	],
);

my $lbFibCompute = $uFib->makeLabel($rtFib, "FibCompute", undef, sub {
	my $row = $_[1]->getRow();
	my $prev = $row->get("cur");
	my $cur = $prev + $row->get("prev");
	my $iter = $row->get("iter") - 1;
	$uFib->makeHashCall($iter > 0? $frFib->getLabel("next") : $lbPrint, $_[1]->getOpcode(),
		iter => $iter,
		cur => $cur,
		prev => $prev,
	);
}) or confess "$!";

# End of streaming function
###

# binding to run the Triceps steps in a loop
my $fbFibLoop = Triceps::FnBinding->new(
	name => "FibLoop",
	on => $frFib,
	withTray => 1,
	labels => [
		next => $lbFibCompute,
	],
);

my $lbMain = $uFib->makeLabel($rtFib, "Main", undef, sub {
	my $row = $_[1]->getRow();
	{
		my $ab = Triceps::AutoFnBind->new($frFib, $fbFibLoop);

		# send the request into the loop
		$uFib->makeHashCall($lbFibCompute, $_[1]->getOpcode(),
			iter => $row->get("iter"),
			cur => 0, # the "0-th" number
			prev => 1,
		);

		# now keep cycling the loop until it's all done
		while (!$fbFibLoop->trayEmpty()) {
			$fbFibLoop->callTray();
		}
	}
	&send(" is Fibonacci number ", $row->get("iter"), "\n");
}) or confess "$!";

while(&readLine) {
	chomp;
	my @data = split(/,/);
	$uFib->makeArrayCall($lbMain, @data);
	$uFib->drainFrame(); # just in case, for completeness
}

} # doFibFn2

@input = (
	"OP_INSERT,1\n",
	"OP_DELETE,2\n",
	"OP_INSERT,5\n",
	"OP_INSERT,6\n",
);
$result = undef;
&doFibFn2();
#print $result;
ok($result, 
'> OP_INSERT,1
1 is Fibonacci number 1
> OP_DELETE,2
1 is Fibonacci number 2
> OP_INSERT,5
5 is Fibonacci number 5
> OP_INSERT,6
8 is Fibonacci number 6
');

############################################################
# A version of Collapse that uses the binding in flushing.

package FnCollapse;

our @ISA=qw(Triceps::Collapse);

sub new # ($class, $optName => $optValue, ...)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	# Now add an FnReturn to the output of the dataset's tables.
	# One return is enough for both.
	# Also create the bindings for sending the data.
	foreach my $dataset (values %{$self->{datasets}}) {
		my $fret = Triceps::FnReturn->new(
			name => $self->{name} . "." . $dataset->{name} . ".retTbl",
			labels => [
				del => $dataset->{tbDelete}->getOutputLabel(),
				ins => $dataset->{tbInsert}->getOutputLabel(),
			],
		);
		$dataset->{fret} = $fret;

		# these variables will be compiled into the binding snippets
		my $lbOut = $dataset->{lbOut};
		my $unit = $self->{unit};
		my $OP_INSERT = &Triceps::OP_INSERT;
		my $OP_DELETE = &Triceps::OP_DELETE;

		my $fbind = Triceps::FnBinding->new(
			name => $self->{name} . "." . $dataset->{name} . ".bndTbl",
			on => $fret,
			unit => $unit,
			labels => [
				del => sub {
					if ($_[1]->isDelete()) {
						$unit->call($lbOut->makeRowop($OP_DELETE, $_[1]->getRow()));
					}
				},
				ins => sub {
					if ($_[1]->isDelete()) {
						$unit->call($lbOut->makeRowop($OP_INSERT, $_[1]->getRow()));
					}
				},
			],
		);
		$dataset->{fbind} = $fbind;
	}
	bless $self, $class;
	return $self;
}

# A function that clears a table (not a method, no $self).
sub _clearTable # ($table)
{
	my $table = shift;
	my $next;
	for (my $rh = $table->begin(); !$rh->isNull(); $rh = $next) {
		$next = $rh->next(); # advance the irerator before removing
		$table->remove($rh);
	}
}

# Override the base-class flush with a different implementation.
sub flush # ($self)
{
	my $self = shift;
	foreach my $dataset (values %{$self->{datasets}}) {
		# The binding takes care of producing and directing
		# the output. AutoFnBind will unbind when the block ends.
		my $ab = Triceps::AutoFnBind->new(
			$dataset->{fret} => $dataset->{fbind}
		);
		_clearTable($dataset->{tbDelete});
		_clearTable($dataset->{tbInsert});
	}
}

package main;

############################################################
# A touch-test of FnCollapse, copied and adapted from xCollapse.t.

sub doCollapse1 {

my $unit = Triceps::Unit->new("unit") or confess "$!";

our $rtData = Triceps::RowType->new(
	# mostly copied from the traffic aggregation example
	local_ip => "string",
	remote_ip => "string",
	bytes => "int64",
) or confess "$!";

my $collapse = FnCollapse->new(
	unit => $unit,
	name => "collapse",
	data => [
		name => "idata",
		rowType => $rtData,
		key => [ "local_ip", "remote_ip" ],
	],
);

my $lbPrint = makePrintLabel("print", $collapse->getOutputLabel("idata"));

my $lbInput = $collapse->getInputLabel("idata");

while(&readLine) {
	chomp;
	my @data = split(/,/); # starts with a command, then string opcode
	my $type = shift @data;
	if ($type eq "data") {
		my $rowop = $lbInput->makeRowopArray(@data);
		$unit->call($rowop);
		$unit->drainFrame(); # just in case, for completeness
	} elsif ($type eq "flush") {
		$collapse->flush();
	}
}

} # doCollapse1

{
# data and result copied from xCollapse.t
my @inputData = (
	"data,OP_INSERT,1.2.3.4,5.6.7.8,100\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,1000\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,1000\n",
	"flush\n",
	"data,OP_DELETE,1.2.3.4,5.6.7.8,100\n",
	"data,OP_INSERT,1.2.3.4,5.6.7.8,200\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,2000\n",
	"flush\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,2000\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,3000\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,3000\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,4000\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,4000\n",
	"flush\n",
	# from this point, show the ordering of multiple delete-inserts
	"data,OP_INSERT,1.1.1.1,5.5.5.5,100\n",
	"data,OP_INSERT,2.2.2.2,6.6.6.6,100\n",
	"data,OP_INSERT,3.3.3.3,7.7.7.7,100\n",
	"data,OP_INSERT,4.4.4.4,8.8.8.8,100\n",
	"flush\n",
	"data,OP_DELETE,1.1.1.1,5.5.5.5,100\n",
	"data,OP_DELETE,2.2.2.2,6.6.6.6,100\n",
	"data,OP_DELETE,3.3.3.3,7.7.7.7,100\n",
	"data,OP_DELETE,4.4.4.4,8.8.8.8,100\n",
	"data,OP_INSERT,1.1.1.1,5.5.5.5,200\n",
	"data,OP_INSERT,2.2.2.2,6.6.6.6,200\n",
	"data,OP_INSERT,3.3.3.3,7.7.7.7,200\n",
	"data,OP_INSERT,4.4.4.4,8.8.8.8,200\n",
	"data,OP_DELETE,1.1.1.1,5.5.5.5,200\n",
	"data,OP_DELETE,2.2.2.2,6.6.6.6,200\n",
	"data,OP_DELETE,3.3.3.3,7.7.7.7,200\n",
	"data,OP_DELETE,4.4.4.4,8.8.8.8,200\n",
	"data,OP_INSERT,1.1.1.1,5.5.5.5,300\n",
	"data,OP_INSERT,2.2.2.2,6.6.6.6,300\n",
	"data,OP_INSERT,3.3.3.3,7.7.7.7,300\n",
	"data,OP_INSERT,4.4.4.4,8.8.8.8,300\n",
	"flush\n",
);

# XXX here the result order depends on the hash order
my $expectResult = 
'> data,OP_INSERT,1.2.3.4,5.6.7.8,100
> data,OP_INSERT,1.2.3.4,6.7.8.9,1000
> data,OP_DELETE,1.2.3.4,6.7.8.9,1000
> flush
collapse.idata.out OP_INSERT local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="100" 
> data,OP_DELETE,1.2.3.4,5.6.7.8,100
> data,OP_INSERT,1.2.3.4,5.6.7.8,200
> data,OP_INSERT,1.2.3.4,6.7.8.9,2000
> flush
collapse.idata.out OP_DELETE local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="100" 
collapse.idata.out OP_INSERT local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="200" 
collapse.idata.out OP_INSERT local_ip="1.2.3.4" remote_ip="6.7.8.9" bytes="2000" 
> data,OP_DELETE,1.2.3.4,6.7.8.9,2000
> data,OP_INSERT,1.2.3.4,6.7.8.9,3000
> data,OP_DELETE,1.2.3.4,6.7.8.9,3000
> data,OP_INSERT,1.2.3.4,6.7.8.9,4000
> data,OP_DELETE,1.2.3.4,6.7.8.9,4000
> flush
collapse.idata.out OP_DELETE local_ip="1.2.3.4" remote_ip="6.7.8.9" bytes="2000" 
> data,OP_INSERT,1.1.1.1,5.5.5.5,100
> data,OP_INSERT,2.2.2.2,6.6.6.6,100
> data,OP_INSERT,3.3.3.3,7.7.7.7,100
> data,OP_INSERT,4.4.4.4,8.8.8.8,100
> flush
collapse.idata.out OP_INSERT local_ip="3.3.3.3" remote_ip="7.7.7.7" bytes="100" 
collapse.idata.out OP_INSERT local_ip="2.2.2.2" remote_ip="6.6.6.6" bytes="100" 
collapse.idata.out OP_INSERT local_ip="4.4.4.4" remote_ip="8.8.8.8" bytes="100" 
collapse.idata.out OP_INSERT local_ip="1.1.1.1" remote_ip="5.5.5.5" bytes="100" 
> data,OP_DELETE,1.1.1.1,5.5.5.5,100
> data,OP_DELETE,2.2.2.2,6.6.6.6,100
> data,OP_DELETE,3.3.3.3,7.7.7.7,100
> data,OP_DELETE,4.4.4.4,8.8.8.8,100
> data,OP_INSERT,1.1.1.1,5.5.5.5,200
> data,OP_INSERT,2.2.2.2,6.6.6.6,200
> data,OP_INSERT,3.3.3.3,7.7.7.7,200
> data,OP_INSERT,4.4.4.4,8.8.8.8,200
> data,OP_DELETE,1.1.1.1,5.5.5.5,200
> data,OP_DELETE,2.2.2.2,6.6.6.6,200
> data,OP_DELETE,3.3.3.3,7.7.7.7,200
> data,OP_DELETE,4.4.4.4,8.8.8.8,200
> data,OP_INSERT,1.1.1.1,5.5.5.5,300
> data,OP_INSERT,2.2.2.2,6.6.6.6,300
> data,OP_INSERT,3.3.3.3,7.7.7.7,300
> data,OP_INSERT,4.4.4.4,8.8.8.8,300
> flush
collapse.idata.out OP_DELETE local_ip="3.3.3.3" remote_ip="7.7.7.7" bytes="100" 
collapse.idata.out OP_DELETE local_ip="2.2.2.2" remote_ip="6.6.6.6" bytes="100" 
collapse.idata.out OP_DELETE local_ip="4.4.4.4" remote_ip="8.8.8.8" bytes="100" 
collapse.idata.out OP_DELETE local_ip="1.1.1.1" remote_ip="5.5.5.5" bytes="100" 
collapse.idata.out OP_INSERT local_ip="3.3.3.3" remote_ip="7.7.7.7" bytes="300" 
collapse.idata.out OP_INSERT local_ip="2.2.2.2" remote_ip="6.6.6.6" bytes="300" 
collapse.idata.out OP_INSERT local_ip="4.4.4.4" remote_ip="8.8.8.8" bytes="300" 
collapse.idata.out OP_INSERT local_ip="1.1.1.1" remote_ip="5.5.5.5" bytes="300" 
';

@input = @inputData;
$result = undef;
&doCollapse1();
#print $result;
ok($result, $expectResult);
}

############################################################
# A version of Collapse that uses the binding in flushing
# and keeps the deletes and inserts close in its output.

package FnCollapseClose;

our @ISA=qw(FnCollapse);

sub new # ($class, $optName => $optValue, ...)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	# Now add an FnReturn to the output of the dataset's tables.
	# One return is enough for both.
	# Also create the bindings for sending the data.
	foreach my $dataset (values %{$self->{datasets}}) {
		my $fret = Triceps::FnReturn->new(
			name => $self->{name} . "." . $dataset->{name} . ".retTbl",
			labels => [
				del => $dataset->{tbDelete}->getOutputLabel(),
				ins => $dataset->{tbInsert}->getOutputLabel(),
			],
		);
		$dataset->{fret} = $fret;

		# these variables will be compiled into the binding snippets
		my $lbInsInput = $dataset->{tbInsert}->getInputLabel();
		my $lbOut = $dataset->{lbOut};
		my $unit = $self->{unit};
		my $OP_INSERT = &Triceps::OP_INSERT;
		my $OP_DELETE = &Triceps::OP_DELETE;

		my $fbind = Triceps::FnBinding->new(
			name => $self->{name} . "." . $dataset->{name} . ".bndTbl",
			on => $fret,
			unit => $unit,
			labels => [
				del => sub {
					if ($_[1]->isDelete()) {
						$unit->call($lbOut->makeRowop($OP_DELETE, $_[1]->getRow()));
						# If the INSERT is available after this DELETE, this
						# will produce it.
						$unit->call($lbInsInput->adopt($_[1]));
					}
				},
				ins => sub {
					if ($_[1]->isDelete()) {
						$unit->call($lbOut->makeRowop($OP_INSERT, $_[1]->getRow()));
					}
				},
			],
		);
		$dataset->{fbind} = $fbind;
	}
	bless $self, $class;
	return $self;
}

package main;

############################################################
# A touch-test of FnCollapseClose, exactly the same as doCollapse1
# only using a different collapse class.

sub doCollapse2 {

my $unit = Triceps::Unit->new("unit") or confess "$!";

our $rtData = Triceps::RowType->new(
	# mostly copied from the traffic aggregation example
	local_ip => "string",
	remote_ip => "string",
	bytes => "int64",
) or confess "$!";

my $collapse = FnCollapseClose->new(
	unit => $unit,
	name => "collapse",
	data => [
		name => "idata",
		rowType => $rtData,
		key => [ "local_ip", "remote_ip" ],
	],
);

my $lbPrint = makePrintLabel("print", $collapse->getOutputLabel("idata"));

my $lbInput = $collapse->getInputLabel("idata");

while(&readLine) {
	chomp;
	my @data = split(/,/); # starts with a command, then string opcode
	my $type = shift @data;
	if ($type eq "data") {
		my $rowop = $lbInput->makeRowopArray(@data);
		$unit->call($rowop);
		$unit->drainFrame(); # just in case, for completeness
	} elsif ($type eq "flush") {
		$collapse->flush();
	}
}

} # doCollapse2

{
# data and result copied from xCollapse.t
my @inputData = (
	"data,OP_INSERT,1.2.3.4,5.6.7.8,100\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,1000\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,1000\n",
	"flush\n",
	"data,OP_DELETE,1.2.3.4,5.6.7.8,100\n",
	"data,OP_INSERT,1.2.3.4,5.6.7.8,200\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,2000\n",
	"flush\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,2000\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,3000\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,3000\n",
	"data,OP_INSERT,1.2.3.4,6.7.8.9,4000\n",
	"data,OP_DELETE,1.2.3.4,6.7.8.9,4000\n",
	"flush\n",
	# from this point, show the ordering of multiple delete-inserts
	"data,OP_INSERT,1.1.1.1,5.5.5.5,100\n",
	"data,OP_INSERT,2.2.2.2,6.6.6.6,100\n",
	"data,OP_INSERT,3.3.3.3,7.7.7.7,100\n",
	"data,OP_INSERT,4.4.4.4,8.8.8.8,100\n",
	"flush\n",
	"data,OP_DELETE,1.1.1.1,5.5.5.5,100\n",
	"data,OP_DELETE,2.2.2.2,6.6.6.6,100\n",
	"data,OP_DELETE,3.3.3.3,7.7.7.7,100\n",
	"data,OP_DELETE,4.4.4.4,8.8.8.8,100\n",
	"data,OP_INSERT,1.1.1.1,5.5.5.5,200\n",
	"data,OP_INSERT,2.2.2.2,6.6.6.6,200\n",
	"data,OP_INSERT,3.3.3.3,7.7.7.7,200\n",
	"data,OP_INSERT,4.4.4.4,8.8.8.8,200\n",
	"data,OP_DELETE,1.1.1.1,5.5.5.5,200\n",
	"data,OP_DELETE,2.2.2.2,6.6.6.6,200\n",
	"data,OP_DELETE,3.3.3.3,7.7.7.7,200\n",
	"data,OP_DELETE,4.4.4.4,8.8.8.8,200\n",
	"data,OP_INSERT,1.1.1.1,5.5.5.5,300\n",
	"data,OP_INSERT,2.2.2.2,6.6.6.6,300\n",
	"data,OP_INSERT,3.3.3.3,7.7.7.7,300\n",
	"data,OP_INSERT,4.4.4.4,8.8.8.8,300\n",
	"flush\n",
);

# XXX here the result order depends on the hash order
my $expectResult = 
'> data,OP_INSERT,1.2.3.4,5.6.7.8,100
> data,OP_INSERT,1.2.3.4,6.7.8.9,1000
> data,OP_DELETE,1.2.3.4,6.7.8.9,1000
> flush
collapse.idata.out OP_INSERT local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="100" 
> data,OP_DELETE,1.2.3.4,5.6.7.8,100
> data,OP_INSERT,1.2.3.4,5.6.7.8,200
> data,OP_INSERT,1.2.3.4,6.7.8.9,2000
> flush
collapse.idata.out OP_DELETE local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="100" 
collapse.idata.out OP_INSERT local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="200" 
collapse.idata.out OP_INSERT local_ip="1.2.3.4" remote_ip="6.7.8.9" bytes="2000" 
> data,OP_DELETE,1.2.3.4,6.7.8.9,2000
> data,OP_INSERT,1.2.3.4,6.7.8.9,3000
> data,OP_DELETE,1.2.3.4,6.7.8.9,3000
> data,OP_INSERT,1.2.3.4,6.7.8.9,4000
> data,OP_DELETE,1.2.3.4,6.7.8.9,4000
> flush
collapse.idata.out OP_DELETE local_ip="1.2.3.4" remote_ip="6.7.8.9" bytes="2000" 
> data,OP_INSERT,1.1.1.1,5.5.5.5,100
> data,OP_INSERT,2.2.2.2,6.6.6.6,100
> data,OP_INSERT,3.3.3.3,7.7.7.7,100
> data,OP_INSERT,4.4.4.4,8.8.8.8,100
> flush
collapse.idata.out OP_INSERT local_ip="3.3.3.3" remote_ip="7.7.7.7" bytes="100" 
collapse.idata.out OP_INSERT local_ip="2.2.2.2" remote_ip="6.6.6.6" bytes="100" 
collapse.idata.out OP_INSERT local_ip="4.4.4.4" remote_ip="8.8.8.8" bytes="100" 
collapse.idata.out OP_INSERT local_ip="1.1.1.1" remote_ip="5.5.5.5" bytes="100" 
> data,OP_DELETE,1.1.1.1,5.5.5.5,100
> data,OP_DELETE,2.2.2.2,6.6.6.6,100
> data,OP_DELETE,3.3.3.3,7.7.7.7,100
> data,OP_DELETE,4.4.4.4,8.8.8.8,100
> data,OP_INSERT,1.1.1.1,5.5.5.5,200
> data,OP_INSERT,2.2.2.2,6.6.6.6,200
> data,OP_INSERT,3.3.3.3,7.7.7.7,200
> data,OP_INSERT,4.4.4.4,8.8.8.8,200
> data,OP_DELETE,1.1.1.1,5.5.5.5,200
> data,OP_DELETE,2.2.2.2,6.6.6.6,200
> data,OP_DELETE,3.3.3.3,7.7.7.7,200
> data,OP_DELETE,4.4.4.4,8.8.8.8,200
> data,OP_INSERT,1.1.1.1,5.5.5.5,300
> data,OP_INSERT,2.2.2.2,6.6.6.6,300
> data,OP_INSERT,3.3.3.3,7.7.7.7,300
> data,OP_INSERT,4.4.4.4,8.8.8.8,300
> flush
collapse.idata.out OP_DELETE local_ip="3.3.3.3" remote_ip="7.7.7.7" bytes="100" 
collapse.idata.out OP_INSERT local_ip="3.3.3.3" remote_ip="7.7.7.7" bytes="300" 
collapse.idata.out OP_DELETE local_ip="2.2.2.2" remote_ip="6.6.6.6" bytes="100" 
collapse.idata.out OP_INSERT local_ip="2.2.2.2" remote_ip="6.6.6.6" bytes="300" 
collapse.idata.out OP_DELETE local_ip="4.4.4.4" remote_ip="8.8.8.8" bytes="100" 
collapse.idata.out OP_INSERT local_ip="4.4.4.4" remote_ip="8.8.8.8" bytes="300" 
collapse.idata.out OP_DELETE local_ip="1.1.1.1" remote_ip="5.5.5.5" bytes="100" 
collapse.idata.out OP_INSERT local_ip="1.1.1.1" remote_ip="5.5.5.5" bytes="300" 
';

@input = @inputData;
$result = undef;
&doCollapse2();
#print $result;
ok($result, $expectResult);
}

