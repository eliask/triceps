#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The example of queries in TQL (Triceps/Trivial Query Language).

#########################

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 1 };
use Triceps;
use Triceps::X::TestFeed qw(:all);
use Carp;
ok(1); # If we made it this far, we're ok.

use strict;

#########################
# The line-splitting.

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################
# Common Triceps types.

# The basic table type to be used for querying.
our $rtTrade = Triceps::RowType->new(
	id => "int32", # trade unique id
	symbol => "string", # symbol traded
	price => "float64",
	size => "float64", # number of shares traded
) or confess "$!";

our $ttWindow = Triceps::TableType->new($rtTrade)
	->addSubIndex("bySymbol", 
		Triceps::SimpleOrderedIndex->new(symbol => "ASC")
			->addSubIndex("last2",
				Triceps::IndexType->newFifo(limit => 2)
			)
	)
	or confess "$!";
$ttWindow->initialize() or confess "$!";

#########################
# Server with module version 1.

use Triceps::X::Braced qw(split_braced);

sub Query1 # ($%tables, $argline)
{
	my $tables = shift;
	my $s = shift;

	$s =~ s/^([^,]*)(,|$)//; # skip the name of the label
	my $q = $1; # the name of the query itself
	&Triceps::X::SimpleServer::outCurBuf("query: $s\n");
	my @cmds = split_braced($s);
	if ($s ne '') {
		&Triceps::X::SimpleServer::outCurBuf("+ERROR,OP_INSERT,$q: mismatched braces in the trailing $s\n");
		return
	}

	# The context for the commands to build up an execution of a query.
	my $ctx = {};
	# The query will be built in a separate unit
	$ctx->{u} = Triceps::Unit->new("u_${q}");
	$ctx->{prev} = undef; # will contain the output of the previous command in a pipeline
	if (!  eval {
		my $cleaner = $ctx->{u}->makeClearingTrigger();
		foreach my $cmd (@cmds) {
			&Triceps::X::SimpleServer::outCurBuf("+cmd, $cmd\n");
		}
		1; # means that everything went OK
	}) {
		# XXX this won't work well with the multi-line errors
		&Triceps::X::SimpleServer::outCurBuf("+ERROR,OP_INSERT,$q: error: $@\n");
		return
	}
}

sub runQuery1
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";

# The information about tables, for querying.
my %tables;
$tables{$tWindow->getName()} = $tWindow;

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{"query"} = sub { Query1(\%tables, @_); };
$dispatch{"exit"} = \&Triceps::X::SimpleServer::exitFunc;

Triceps::X::DumbClient::run(\%dispatch);
};

# the same input and result gets reused mutiple times
my @inputQuery1 = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"query,{read table tWindow} {project fields {symbol price}}\n",
	"query,{read table tWindow} {project fields {symbol price}\n",
);
my $expectQuery1 = 
'> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> qWindow,OP_INSERT
> tWindow,OP_INSERT,5,AAA,30,30
> qWindow,OP_INSERT
qWindow.out,OP_INSERT,1,AAA,10,10
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_NOP,,,,
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,5,AAA,30,30
qWindow.out,OP_NOP,,,,
';

setInputLines(@inputQuery1);
&runQuery1();
#print &getResultLines();
#ok(&getResultLines(), $expectQuery1);

