#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The example of queries in TQL (Triceps/Trivial Query Language).

#########################

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 2 };
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

use Triceps::X::Braced qw(split_braced bunquote bunquote_all);

sub tqlRead # ($ctx, @args)
{
	my $ctx = shift;
	die "The read command may not be used in the middle of a pipeline.\n" 
		if (defined($ctx->{prev}));
	my $opts = {};
	# XXX add ways to unquote when option parsing?
	&Triceps::Opt::parse("read", $opts, {
		table => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);

	my $fret = $ctx->{fretDumps};
	my $tabname = bunquote($opts->{table});

	die ("Read found no such table '$tabname'\n")
		unless (exists $ctx->{tables}{$tabname});
	my $unit = $ctx->{u};
	my $table = $ctx->{tables}{$tabname};
	my $lab = $unit->makeDummyLabel($table->getRowType(), "lb" . $ctx->{id} . "read");
	$ctx->{next} = $lab;

	my $code = sub {
		Triceps::FnBinding::call(
			name => "bind" . $ctx->{id} . "read",
			unit => $unit,
			on => $fret,
			labels => [
				$tabname => $lab,
			],
			code => sub {
				$table->dumpAll();
			},
		);
	};
	push @{$ctx->{actions}}, $code;
}

sub tqlProject # ($ctx, @args)
{
	my $ctx = shift;
	die "The project command requires a pipeline input.\n" 
		unless (defined($ctx->{prev}));
	my $opts = {};
	&Triceps::Opt::parse("project", $opts, {
		fields => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	
	my @patterns = bunquote_all(split_braced($opts->{fields}));

	my $rtIn = $ctx->{prev}->getRowType();
	my @inFields = $rtIn->getFieldNames();
	my @pairs =  &Triceps::Fields::filterToPairs("project", \@inFields, \@patterns);
	my ($rtOut, $projectFunc) = &Triceps::Fields::makeTranslation(
		rowTypes => [ $rtIn ],
		filterPairs => [ \@pairs ],
	);

	my $unit = $ctx->{u};
	my $lab = $unit->makeDummyLabel($rtOut, "lb" . $ctx->{id} . "project");
	my $labin = $unit->makeLabel($rtIn, "lb" . $ctx->{id} . "project.in", undef, sub {
		$unit->call($lab->makeRowop($_[1]->getOpcode(), &$projectFunc($_[1]->getRow()) ));
	});
	$ctx->{prev}->chain($labin);
	$ctx->{next} = $lab;
}

sub tqlPrint # ($ctx, @args)
{
	my $ctx = shift;
	die "The print command may not be used at the start of a pipeline.\n" 
		unless (defined($ctx->{prev}));
	my $opts = {};
	&Triceps::Opt::parse("print", $opts, {
		tokenized => [ 1, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	my $tokenized = bunquote($opts->{tokenized}) + 0;

	# XXX This gets the printed label name from the auto-generated label name,
	# which is not a good practice.
	# XXX Should have a custom query name somewhere in the context?
	if ($tokenized) {
		# print in the tokenized format
		my $prev = $ctx->{prev};
		my $lab = $ctx->{u}->makeLabel($prev->getRowType(), 
			"lb" . $ctx->{id} . "print", undef, sub {
				&Triceps::X::SimpleServer::outCurBuf($_[1]->printP() . "\n");
			});
		$prev->chain($lab);
	} else {
		my $lab = Triceps::X::SimpleServer::makeServerOutLabel($ctx->{prev});
	}

	$ctx->{next} = undef; # end of the pipeline
	# XXX add an end-of-data notification
}

our %tqlDispatch = (
	read => \&tqlRead,
	project => \&tqlProject,
	print => \&tqlPrint,
);

sub Query1 # (\%tables, $fretDumps, $argline)
{
	my $tables = shift;
	my $fretDumps = shift;
	my $s = shift;

	$s =~ s/^([^,]*)(,|$)//; # skip the name of the label
	my $q = $1; # the name of the query itself
	#&Triceps::X::SimpleServer::outCurBuf("+DEBUGquery: $s\n");
	my @cmds = split_braced($s);
	if ($s ne '') {
		&Triceps::X::SimpleServer::outCurBuf("+ERROR,OP_INSERT,$q: mismatched braces in the trailing $s\n");
		return
	}

	# The context for the commands to build up an execution of a query.
	my $ctx = {};
	# The query will be built in a separate unit
	$ctx->{tables} = $tables;
	$ctx->{fretDumps} = $fretDumps;
	$ctx->{u} = Triceps::Unit->new("u_${q}");
	$ctx->{prev} = undef; # will contain the output of the previous command in the pipeline
	$ctx->{actions} = []; # code that will run the pipeline
	$ctx->{id} = 0; # a unique id for auto-generated objects

	my $cleaner = $ctx->{u}->makeClearingTrigger();
	if (!  eval {
		foreach my $cmd (@cmds) {
			#&Triceps::X::SimpleServer::outCurBuf("+DEBUGcmd, $cmd\n");
			my @args = split_braced($cmd);
			my $argv0 = bunquote(shift @args);
			# The rest of @args do not get unquoted here!
			die "No such TQL command '$argv0'\n" unless exists $tqlDispatch{$argv0};
			# XXX do something better with the errors, show the failing command...
			$ctx->{id}++;
			&{$tqlDispatch{$argv0}}($ctx, @args);
			# Each command must set its result label (even if an undef) into
			# $ctx->{next}.
			die "Internal error in the command $argv0: missing result definition\n"
				unless (exists $ctx->{next});
			$ctx->{prev} = $ctx->{next};
			delete $ctx->{next};
		}
		if (defined $ctx->{prev}) {
			# implicitly print the result of the pipeline, no options
			&{$tqlDispatch{"print"}}($ctx);
		}

		# Now run the pipeline
		foreach my $code (@{$ctx->{actions}}) {
			&$code;
		}

		# Now run the pipeline
		1; # means that everything went OK
	}) {
		# XXX this won't work well with the multi-line errors
		&Triceps::X::SimpleServer::outCurBuf("+ERROR,OP_INSERT,$q: error: $@\n");
		return
	}
}

# Build an FnReturn with dump labels of all the tables.
# The labels in return will be named as their table.
# @param name - name for the FnReturn
# @param \%tables - a hash (table name => table object), the name from this
#     hash will be used for FnReturn (it should probably be the same as the
#     table name but no guarantees there).
sub collectDumps # ($name, \%tables)
{
	my $name = shift;
	my $tables = shift;
	my @labels;
	my ($k, $v);
	while (($k, $v) = each %$tables) {
		push @labels, $k, $v->getDumpLabel();
	}
	return Triceps::FnReturn->new(
		name => $name,
		labels => \@labels,
	);
}

sub runQuery1
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";

# The information about tables, for querying.
my %tables;
$tables{$tWindow->getName()} = $tWindow;
my $fretDumps = collectDumps("fretDumps", \%tables);

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{"query"} = sub { Query1(\%tables, $fretDumps, @_); };
$dispatch{"exit"} = \&Triceps::X::SimpleServer::exitFunc;

Triceps::X::DumbClient::run(\%dispatch);
};

# the same input and result gets reused mutiple times
my @inputQuery1 = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"query,{read table tWindow}\n",
	"query,{read table tWindow} {project fields {symbol price}} {print tokenized 0}\n",
	"query,{read table tWindow} {project fields {symbol price}}\n",
);
my $expectQuery1 = 
'> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> tWindow,OP_INSERT,5,AAA,30,30
> query,{read table tWindow}
> query,{read table tWindow} {project fields {symbol price}} {print tokenized 0}
> query,{read table tWindow} {project fields {symbol price}}
lb1read OP_INSERT id="3" symbol="AAA" price="20" size="20" 
lb1read OP_INSERT id="5" symbol="AAA" price="30" size="30" 
lb2project,OP_INSERT,AAA,20
lb2project,OP_INSERT,AAA,30
lb2project OP_INSERT symbol="AAA" price="20" 
lb2project OP_INSERT symbol="AAA" price="30" 
';

setInputLines(@inputQuery1);
&runQuery1();
#print &getResultLines();
ok(&getResultLines(), $expectQuery1);

