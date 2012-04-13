#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The examples of joins.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 3 };
use Triceps;
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

# a template to make a label that prints the data passing through another label
sub makePrintLabel($$) # ($print_label_name, $parent_label)
{
	my $name = shift;
	my $lbParent = shift;
	my $lb = $lbParent->getUnit()->makeLabel($lbParent->getType(), $name,
		undef, sub { # (label, rowop)
			&send($_[1]->printP(), "\n");
		}) or die "$!";
	$lbParent->chain($lb) or die "$!";
	return $lb;
}

#########################
# common row types and such, for translation of the external account
# numbers from various external systems into the internal number

our $rtInTrans = Triceps::RowType->new( # a transaction received
	id => "int32", # the transaction id
	acctSrc => "string", # external system that sent us a transaction
	acctXtrId => "string", # its name of the account of the transaction
	amount => "int32", # the amount of transaction (int is easier to check)
) or die "$!";

our $rtAccounts = Triceps::RowType->new( # account translation map
	source => "string", # external system that sent us a transaction
	external => "string", # its name of the account of the transaction
	internal => "int32", # our internal account id
) or die "$!";

our $ttAccounts = Triceps::TableType->new($rtAccounts)
	->addSubIndex("lookupSrcExt", # quick look-up by source and external id
		Triceps::IndexType->newHashed(key => [ "source", "external" ])
	)
	->addSubIndex("iterateSrc", # for iteration in order grouped by source
		Triceps::IndexType->newHashed(key => [ "source" ])
		->addSubIndex("iterateSrcExt", 
			Triceps::IndexType->newHashed(key => [ "external" ])
		)
	)
	->addSubIndex("lookupIntGroup", # quick look-up by internal id (to multiple externals)
		Triceps::IndexType->newHashed(key => [ "internal" ])
		->addSubIndex("lookupInt", Triceps::IndexType->newFifo())
	)
or die "$!";
$ttAccounts->initialize() or die "$!";

my @commonInput = (
	"acct,OP_INSERT,source1,999,1\n",
	"acct,OP_INSERT,source1,2011,2\n",
	"acct,OP_INSERT,source2,ABCD,1\n",
	"trans,OP_INSERT,1,source1,999,100\n", 
	"trans,OP_INSERT,2,source2,ABCD,200\n", 
	"trans,OP_INSERT,3,source2,QWERTY,200\n", 
	"acct,OP_INSERT,source2,QWERTY,2\n",
	"trans,OP_DELETE,3,source2,QWERTY,200\n", 
	"acct,OP_DELETE,source1,999,1\n",
);

#########################
# perform a LookupJoin, with a left join

sub doLookupLeft {

our $uJoin = Triceps::Unit->new("uJoin") or die "$!";

our $tAccounts = $uJoin->makeTable($ttAccounts, 
	&Triceps::EM_CALL, "tAccounts") or die "$!";

our $join = Triceps::LookupJoin->new(
	unit => $uJoin,
	name => "join",
	leftRowType => $rtInTrans,
	rightTable => $tAccounts,
	rightIdxPath => ["lookupSrcExt"],
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 1,
); # would die by itself on an error

# label to print the changes to the detailed stats
makePrintLabel("lbPrintPackets", $join->getOutputLabel());

while(&readLine) {
	chomp;
	my @data = split(/,/); # starts with a command, then string opcode
	my $type = shift @data;
	if ($type eq "acct") {
		$uJoin->makeArrayCall($tAccounts->getInputLabel(), @data)
			or die "$!";
	} elsif ($type eq "trans") {
		$uJoin->makeArrayCall($join->getInputLabel(), @data)
			or die "$!";
	}
	$uJoin->drainFrame(); # just in case, for completeness
}

} # doLookupLeft

@input = @commonInput;
$result = undef;
&doLookupLeft();
#print $result;
ok($result, 
'acct,OP_INSERT,source1,999,1
acct,OP_INSERT,source1,2011,2
acct,OP_INSERT,source2,ABCD,1
trans,OP_INSERT,1,source1,999,100
join.out OP_INSERT id="1" acctSrc="source1" acctXtrId="999" amount="100" acct="1" 
trans,OP_INSERT,2,source2,ABCD,200
join.out OP_INSERT id="2" acctSrc="source2" acctXtrId="ABCD" amount="200" acct="1" 
trans,OP_INSERT,3,source2,QWERTY,200
join.out OP_INSERT id="3" acctSrc="source2" acctXtrId="QWERTY" amount="200" 
acct,OP_INSERT,source2,QWERTY,2
trans,OP_DELETE,3,source2,QWERTY,200
join.out OP_DELETE id="3" acctSrc="source2" acctXtrId="QWERTY" amount="200" acct="2" 
acct,OP_DELETE,source1,999,1
');

#########################
# perform a LookupJoin, with a full join and leftFromLabel

sub doLookupFull {

our $uJoin = Triceps::Unit->new("uJoin") or die "$!";

our $tAccounts = $uJoin->makeTable($ttAccounts, 
	&Triceps::EM_CALL, "tAccounts") or die "$!";

our $lbTrans = $uJoin->makeDummyLabel($rtInTrans, "lbTrans");

our $join = Triceps::LookupJoin->new(
	name => "join",
	leftFromLabel => $lbTrans,
	rightTable => $tAccounts,
	rightIdxPath => ["lookupSrcExt"],
	leftFields => [ "id", "amount" ],
	#leftFields => [ "!acct.*", ".*" ],
	fieldsLeftFirst => 0,
	rightFields => [ "internal/acct" ],
	by => [ "acctSrc" => "source", "acctXtrId" => "external" ],
	isLeft => 0,
); # would die by itself on an error

# label to print the changes to the detailed stats
makePrintLabel("lbPrintPackets", $join->getOutputLabel());

while(&readLine) {
	chomp;
	my @data = split(/,/); # starts with a command, then string opcode
	my $type = shift @data;
	if ($type eq "acct") {
		$uJoin->makeArrayCall($tAccounts->getInputLabel(), @data)
			or die "$!";
	} elsif ($type eq "trans") {
		$uJoin->makeArrayCall($lbTrans, @data)
			or die "$!";
	}
	$uJoin->drainFrame(); # just in case, for completeness
}

} # doLookupFull

@input = @commonInput;
$result = undef;
&doLookupFull();
#print $result;
ok($result, 
'acct,OP_INSERT,source1,999,1
acct,OP_INSERT,source1,2011,2
acct,OP_INSERT,source2,ABCD,1
trans,OP_INSERT,1,source1,999,100
join.out OP_INSERT acct="1" id="1" amount="100" 
trans,OP_INSERT,2,source2,ABCD,200
join.out OP_INSERT acct="1" id="2" amount="200" 
trans,OP_INSERT,3,source2,QWERTY,200
acct,OP_INSERT,source2,QWERTY,2
trans,OP_DELETE,3,source2,QWERTY,200
join.out OP_DELETE acct="2" id="3" amount="200" 
acct,OP_DELETE,source1,999,1
');
