#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The example of queries in TQL (Triceps/Trivial Query Language).

#########################

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 3 };
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
# Represents the trades reports.
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

# Represents the static information about a company.
our $rtSymbol = Triceps::RowType->new(
	symbol => "string", # symbol name
	name => "string", # the official company name
	eps => "float64", # last quarter earnings per share
) or confess "$!";

our $ttSymbol = Triceps::TableType->new($rtSymbol)
	->addSubIndex("bySymbol", 
		Triceps::IndexType->newHashed(key => [ "symbol" ])
	)
	or confess "$!";
$ttSymbol->initialize() or confess "$!";

#########################
# Server with module version 1.

# The Safe module doesn't seem capable of importing the external
# symbols from inside a package. So put this import outside the
# package.
sub _Triceps_X_Tql_share_safe_rowget # ($safe)
{
	my $safe = shift;
	$safe->share('Triceps::Row::get');
}

package Triceps::X::Tql;

use Carp;
use Triceps::X::Braced qw(:all);
use Safe;

sub _tqlRead # ($ctx, @args)
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

sub _tqlProject # ($ctx, @args)
{
	my $ctx = shift;
	die "The project command may not be used at the start of a pipeline.\n" 
		unless (defined($ctx->{prev}));
	my $opts = {};
	&Triceps::Opt::parse("project", $opts, {
		fields => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	
	my $patterns = split_braced_final($opts->{fields});

	my $rtIn = $ctx->{prev}->getRowType();
	my @inFields = $rtIn->getFieldNames();
	my @pairs =  &Triceps::Fields::filterToPairs("project", \@inFields, $patterns);
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

sub _tqlPrint # ($ctx, @args)
{
	my $ctx = shift;
	die "The print command may not be used at the start of a pipeline.\n" 
		unless (defined($ctx->{prev}));
	my $opts = {};
	&Triceps::Opt::parse("print", $opts, {
		tokenized => [ 1, undef ],
	}, @_);
	my $tokenized = bunquote($opts->{tokenized}) + 0;

	# XXX This gets the printed label name from the auto-generated label name,
	# which is not a good practice.
	# XXX Should have a custom query name somewhere in the context?
	my $prev = $ctx->{prev};
	if ($tokenized) {
		# print in the tokenized format
		my $lab = $ctx->{u}->makeLabel($prev->getRowType(), 
			"lb" . $ctx->{id} . "print", undef, sub {
				&Triceps::X::SimpleServer::outCurBuf($_[1]->printP() . "\n");
			});
		$prev->chain($lab);
	} else {
		my $lab = Triceps::X::SimpleServer::makeServerOutLabel($ctx->{prev});
	}

	# The end-of-data notification. It will run after the current pipeline
	# finishes.
	my $prevname = $prev->getName();
	push @{$ctx->{actions}}, sub {
		&Triceps::X::SimpleServer::outCurBuf("+EOD,OP_NOP,$prevname\n");
	};

	$ctx->{next} = undef; # end of the pipeline
}

sub _tqlJoin # ($ctx, @args)
{
	my $ctx = shift;
	die "The join command may not be used at the start of a pipeline.\n" 
		unless (defined($ctx->{prev}));
	my $opts = {};
	&Triceps::Opt::parse("join", $opts, {
		table => [ undef, \&Triceps::Opt::ck_mandatory ],
		rightIdxPath => [ undef, \&Triceps::Opt::ck_mandatory ],
		by => [ undef, undef ],
		byLeft => [ undef, undef ],
		leftFields => [ undef, undef ],
		rightFields => [ undef, undef ],
		type => [ "inner", undef ],
	}, @_);

	my $tabname = bunquote($opts->{table});
	die ("Join found no such table '$tabname'\n")
		unless (exists $ctx->{tables}{$tabname});
	my $table = $ctx->{tables}{$tabname};

	&Triceps::Opt::checkMutuallyExclusive("join", 1, "by", $opts->{by}, "byLeft", $opts->{byLeft});
	my $by = split_braced_final($opts->{by});
	my $byLeft = split_braced_final($opts->{byLeft});

	my $rightIdxPath = split_braced_final($opts->{rightIdxPath});

	my $isLeft = 0; # default for inner join
	my $type = $opts->{type};
	if ($type eq "inner") {
		# already default
	} elsif ($type eq "left") {
		$isLeft = 1;
	} else {
		die "Unsupported value '$type' of option 'type'.\n"
	}

	my $leftFields = split_braced_final($opts->{leftFields});
	my $rightFields = split_braced_final($opts->{rightFields});

	# Build the filtering-out of the duplicate key fields on the right.
	# Similar to what JoinTwo does.
	my($rightIdxType, @rightkeys) = $table->getType()->findIndexKeyPath(@$rightIdxPath);
	if (!defined($rightFields)) {
		$rightFields = [ ".*" ]; # the implicit pass-all
	}
	unshift(@$rightFields, map("!$_", @rightkeys) );

	my $unit = $ctx->{u};
	my $join = Triceps::LookupJoin->new(
		name => "join" . $ctx->{id},
		unit => $unit,
		leftFromLabel => $ctx->{prev},
		rightTable => $table,
		rightIdxPath => $rightIdxPath,
		leftFields => $leftFields,
		rightFields => $rightFields,
		by => $by,
		byLeft => $byLeft,
		isLeft => $isLeft,
	);
	
	$ctx->{next} = $join->getOutputLabel();
}

# Replace a field name with the code that would get the field
# from a variable containing a row. The row definition in hash
# formatr is used to check up-front that the field exists.
sub replaceFieldRef # (\%def, $field)
{
	my $def = shift;
	my $field = shift;
	die "Unknown field '$field'; have fields: " . join(", ", keys %$def) . ".\n"
		unless (exists ${$def}{$field});
	#return '$_[0]->get("' . quotemeta($field) . '")';
	return '&Triceps::Row::get($_[0], "' . quotemeta($field) . '")';
}

sub _tqlWhere # ($ctx, @args)
{
	my $ctx = shift;
	die "The where command may not be used at the start of a pipeline.\n" 
		unless (defined($ctx->{prev}));
	my $opts = {};
	&Triceps::Opt::parse("where", $opts, {
		istrue => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);

	# Here only the keys (field names) will be important, the values
	# (field types) will be ignored.
	my $rt = $ctx->{prev}->getRowType();
	my %def = $rt->getdef();

	my $expr = bunquote($opts->{istrue});
	$expr =~ s/\$\%(\w+)/&replaceFieldRef(\%def, $1)/ge;

	my $safe = new Safe; 
	# This allows for the exploits that run the process out of memory,
	# but the danger is in the highly useful functions, so better take this risk.
	$safe->permit(qw(:base_core :base_mem :base_math sprintf));
	::_Triceps_X_Tql_share_safe_rowget($safe);

	my $compiled = $safe->reval("sub { $expr }", 1);
	die "$@" if($@);

	my $unit = $ctx->{u};
	my $lab = $unit->makeDummyLabel($rt, "lb" . $ctx->{id} . "where");
	my $labin = $unit->makeLabel($rt, "lb" . $ctx->{id} . "where.in", undef, sub {
		if (&$compiled($_[1]->getRow())) {
			$unit->call($lab->adopt($_[1]));
		}
	});
	$ctx->{prev}->chain($labin);
	$ctx->{next} = $lab;
}

	
our %tqlDispatch = (
	read => \&_tqlRead,
	project => \&_tqlProject,
	print => \&_tqlPrint,
	join => \&_tqlJoin,
	where => \&_tqlWhere,
);

# Perform a query in the context of a SimpleServer.
# The $argline is the full line received by the server and forwarded here;
# it still includes the query command on it.
# May be used only after $self is initialized.
sub query # ($self, $argline)
{
	my $myname = "Triceps::X::Tql::query";

	my $self = shift;
	my $argline = shift;

	confess "$myname: may be used only on an initialized object"
		unless ($self->{initialized});

	$argline =~ s/^([^,]*)(,|$)//; # skip the name of the label
	my $q = $1; # the name of the query itself
	#&Triceps::X::SimpleServer::outCurBuf("+DEBUGquery: $argline\n");
	my @cmds = split_braced($argline);
	if ($argline ne '') {
		# Presumably, the argument line should contain no line feeds, so it should be safe to send back.
		&Triceps::X::SimpleServer::outCurBuf("+ERROR,OP_INSERT,$q: mismatched braces in the trailing $argline\n");
		return
	}

	# The context for the commands to build up an execution of a query.
	# Unlike $self, the context is created afresh for every query.
	my $ctx = {};
	# The query will be built in a separate unit
	$ctx->{tables} = $self->{dispatch};
	$ctx->{fretDumps} = $self->{fret};
	$ctx->{u} = Triceps::Unit->new("${q}.unit");
	$ctx->{prev} = undef; # will contain the output of the previous command in the pipeline
	$ctx->{actions} = []; # code that will run the pipeline
	$ctx->{id} = 0; # a unique id for auto-generated objects

	# It's important to place the clearing trigger outside eval {}. Otherwise the
	# clearing will erase any errors in $@ returned from eval.
	my $cleaner = $ctx->{u}->makeClearingTrigger();
	if (! eval {
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

# There are two ways to create a Tql object:
# (1) Use the option "tables" (possibly, with "tableNames"): the Tql object
# will be immediately initialized with thid list of tables.
# (2) Use no options, and initially create an uninitialized object. Then
# add the tables one by one with addTable(). After all tables are added,
# call initialize().
#
# Options:
# name - name for the object, will be use to derive the sub-object names
# tables (optional) - reference to an array of tables on which the TQL 
#   object will allow queries. The presence of this option triggers the
#   immediate initialization.
# tableNames (optional) - reference to an array of names, under which the tables
#   from the option "tables" will be known to TQL. If absent, the table names
#   will be obtained with getName() for each table.
sub new # ($class, $optName => $optValue, ...)
{
	my $myname = "Triceps::X::Tql";
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		tables => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY", "Triceps::Table") } ],
		tableNames => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
	}, @_);

	if (defined $self->{tables}) {
		if (defined $self->{tableNames}) {
			confess "$myname: the arrays in options 'tables' and 'tableNames' must be of equal size, got "
					. ($#{$self->{tables}} + 1) . " and " . ($#{$self->{tableNames}} + 1)
				unless ($#{$self->{tableNames}} == $#{$self->{tables}});
		} else {
			my @names;
			foreach my $t (@{$self->{tables}}) {
				push @names, $t->getName();
			}
			$self->{tableNames} = \@names;
		}
		initialize($self);
	} else {
		confess "$myname: the option 'tableNames' may not be used without option 'tables'."
			if (defined $self->{tableNames});
	}

	bless $self, $class;
	return $self;
}

# Add one or more named tables, defined in pairs of arguments.
# May be used only while $self is not initialized.
sub addNamedTable # ($self, $name => $table, ...)
{
	my $myname = "Triceps::X::Tql::addNamedTable";
	my $self = shift;

	confess "$myname: may be used only on an uninitialized object"
		if ($self->{initialized});

	while($#_ >= 0) {
		my $name = shift; 
		my $table = shift;

		my $tref = ref $table;
		confess "$myname: the table named '$name' must be of Triceps::Table type, is '$tref'"
			unless ($tref eq "Triceps::Table");

		push @{$self->{tables}}, $table;
		push @{$self->{tableNames}}, $name;
	}
}

# Add one or more tables, using their own names.
# May be used only while $self is not initialized.
sub addTable # ($self, @tables)
{
	my $myname = "Triceps::X::Tql::addTable";
	my $self = shift;

	confess "$myname: may be used only on an uninitialized object"
		if ($self->{initialized});

	for my $table (@_) {
		my $tref = ref $table;
		confess "$myname: the table must be of Triceps::Table type, is '$tref'"
			unless ($tref eq "Triceps::Table");

		push @{$self->{tables}}, $table;
		push @{$self->{tableNames}}, $table->getName();
	}
}

# Initialize the object. After that the tables may not be added any more.
sub initialize # ($self)
{
	my $myname = "Triceps::X::Tql::initialize";
	my $self = shift;

	return if ($self->{initialized});

	my %dispatch;
	my @labels;
	for (my $i = 0; $i <= $#{$self->{tables}}; $i++) {
		my $name = $self->{tableNames}[$i]; 
		my $table = $self->{tables}[$i];

		confess "$myname: found a duplicate table name '$name', all names are: "
				. join(", ", @{$self->{tableNames}})
			if (exists $dispatch{$name});

		$dispatch{$name} = $table;
		push @labels, $name, $table->getDumpLabel();
	}

	$self->{dispatch} = \%dispatch;
	$self->{fret} = Triceps::FnReturn->new(
		name => $self->{name} . ".fret",
		labels => \@labels,
	);

	$self->{initialized} = 1;
}

1;

package main;

sub runTqlQuery1
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $tSymbol = $uTrades->makeTable($ttSymbol, "EM_CALL", "tSymbol")
	or confess "$!";

# The information about tables, for querying.
my $tql = Triceps::X::Tql->new(
	name => "tql",
	tables => [
		$tWindow,
		$tSymbol,
	],
);

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$tSymbol->getName()} = $tSymbol->getInputLabel();
$dispatch{"query"} = sub { $tql->query(@_); };
$dispatch{"exit"} = \&Triceps::X::SimpleServer::exitFunc;

Triceps::X::DumbClient::run(\%dispatch);
};

# the same input and result gets reused mutiple times
my @inputQuery1 = (
	"tSymbol,OP_INSERT,AAA,Absolute Auto Analytics Inc,0.5\n",
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"query,{read table tSymbol}\n",
	"query,{read table tWindow} {project fields {symbol price}} {print tokenized 0}\n",
	"query,{read table tWindow} {project fields {symbol price}}\n",
	"query,{read table tWindow} {join table tSymbol rightIdxPath bySymbol byLeft {symbol}}\n",
	"query,{read table tWindow} {where istrue {\$%price == 20}}\n",
);
my $expectQuery1 = 
'> tSymbol,OP_INSERT,AAA,Absolute Auto Analytics Inc,0.5
> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> tWindow,OP_INSERT,5,AAA,30,30
> query,{read table tSymbol}
> query,{read table tWindow} {project fields {symbol price}} {print tokenized 0}
> query,{read table tWindow} {project fields {symbol price}}
> query,{read table tWindow} {join table tSymbol rightIdxPath bySymbol byLeft {symbol}}
> query,{read table tWindow} {where istrue {$%price == 20}}
lb1read OP_INSERT symbol="AAA" name="Absolute Auto Analytics Inc" eps="0.5" 
+EOD,OP_NOP,lb1read
lb2project,OP_INSERT,AAA,20
lb2project,OP_INSERT,AAA,30
+EOD,OP_NOP,lb2project
lb2project OP_INSERT symbol="AAA" price="20" 
lb2project OP_INSERT symbol="AAA" price="30" 
+EOD,OP_NOP,lb2project
join2.out OP_INSERT id="3" symbol="AAA" price="20" size="20" name="Absolute Auto Analytics Inc" eps="0.5" 
join2.out OP_INSERT id="5" symbol="AAA" price="30" size="30" name="Absolute Auto Analytics Inc" eps="0.5" 
+EOD,OP_NOP,join2.out
lb2where OP_INSERT id="3" symbol="AAA" price="20" size="20" 
+EOD,OP_NOP,lb2where
';

setInputLines(@inputQuery1);
&runTqlQuery1();
#print &getResultLines();
ok(&getResultLines(), $expectQuery1);

################################################################
# Same as Query1 but initializes the Tql object piecemeal.
# (the list of queries used is somewhat reduced).

sub runTqlQuery2
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $tSymbol = $uTrades->makeTable($ttSymbol, "EM_CALL", "tSymbol")
	or confess "$!";

# The information about tables, for querying.
my $tql = Triceps::X::Tql->new(name => "tql");
$tql->addNamedTable(
	window => $tWindow,
	symbol => $tSymbol,
);
# add 2nd time, with different names
$tql->addTable(
	$tWindow,
	$tSymbol,
);
$tql->initialize;

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$tSymbol->getName()} = $tSymbol->getInputLabel();
$dispatch{"query"} = sub { $tql->query(@_); };
$dispatch{"exit"} = \&Triceps::X::SimpleServer::exitFunc;

Triceps::X::DumbClient::run(\%dispatch);
};

# the same input and result gets reused mutiple times
my @inputQuery2 = (
	"tSymbol,OP_INSERT,AAA,Absolute Auto Analytics Inc,0.5\n",
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"query,{read table tSymbol}\n",
	"query,{read table tWindow}\n",
	"query,{read table symbol}\n",
	"query,{read table window}\n",
);
my $expectQuery2 = 
'> tSymbol,OP_INSERT,AAA,Absolute Auto Analytics Inc,0.5
> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> tWindow,OP_INSERT,5,AAA,30,30
> query,{read table tSymbol}
> query,{read table tWindow}
> query,{read table symbol}
> query,{read table window}
lb1read OP_INSERT symbol="AAA" name="Absolute Auto Analytics Inc" eps="0.5" 
+EOD,OP_NOP,lb1read
lb1read OP_INSERT id="3" symbol="AAA" price="20" size="20" 
lb1read OP_INSERT id="5" symbol="AAA" price="30" size="30" 
+EOD,OP_NOP,lb1read
lb1read OP_INSERT symbol="AAA" name="Absolute Auto Analytics Inc" eps="0.5" 
+EOD,OP_NOP,lb1read
lb1read OP_INSERT id="3" symbol="AAA" price="20" size="20" 
lb1read OP_INSERT id="5" symbol="AAA" price="30" size="30" 
+EOD,OP_NOP,lb1read
';

setInputLines(@inputQuery2);
&runTqlQuery2();
#print &getResultLines();
ok(&getResultLines(), $expectQuery2);

