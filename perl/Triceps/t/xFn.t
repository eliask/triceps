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
BEGIN { plan tests => 3 };
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

