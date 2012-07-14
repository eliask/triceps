#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The example of templates for querying a table.

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 14 };
use Triceps;
use Carp;
use Errno qw(EINTR EAGAIN);
use IO::Poll qw(POLLIN POLLOUT POLLHUP);
use IO::Socket;
use IO::Socket::INET;
ok(1); # If we made it this far, we're ok.

use strict;
no warnings;

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
# The server infrastructure

# the socket and buffering control for the main loop;
# they are all indexed by a unique id
our %clients; # client sockets
our %inbufs; # input buffers, collecting the whole lines
our %outbufs; # output buffers
our $poll; # the poll object
our $cur_cli; # the id of the current client being processed
our $srv_exit; # exit when all the client connections are closed

# writing to the output buffers
sub outBuf # ($id, $string)
{
	my $id = shift;
	my $line = shift;
	$outbufs{$id} .= $line;
	# If there is anything to write on a buffer, stop reading from it.
	$poll->mask($clients{$id} => POLLOUT);
}

sub outCurBuf # ($string)
{
	outBuf($cur_cli, @_);
}

sub closeClient # ($id, $h)
{
	my $id = shift;
	my $h = shift;
	$poll->mask($h, 0);
	$h->close();
	delete $clients{$id}; # OK per Perl manual even when iterating
	delete $inbufs{$id};
	delete $outbufs{$id};
}

# The server main loop. Runs with the specified server socket.
# Uses the labels hash to send the incoming data to Triceps.
sub mainLoop # ($srvsock, $%labels)
{
	my $srvsock = shift;
	my $labels = shift;

	my $client_id = 0; # unique strings
	our $poll = IO::Poll->new();

	$srvsock->blocking(0);
	$poll->mask($srvsock => POLLIN);
	$srv_exit = 0;

	while(!$srv_exit || keys %clients != 0) {
		my $r = $poll->poll();
		confess "poll failed: $!" if ($r < 0 && ! $!{EAGAIN} && ! $!{EINTR});

		if ($poll->events($srvsock)) {
			while(1) {
				my $client = $srvsock->accept();
				if (defined $client) {
					$client->blocking(0);
					$clients{++$client_id} = $client;
					# &send("Accepted client $client_id\n");
					$poll->mask($client => (POLLIN|POLLHUP));
				} elsif($!{EAGAIN} || $!{EINTR}) {
					last;
				} else {
					confess "accept failed: $!";
				}
			}
		}

		my ($id, $h, $mask, $n, $s);
		while (($id, $h) = each %clients) {
			$cur_cli = $id;
			$mask = $poll->events($h);
			if (($mask & POLLHUP) && !defined $outbufs{$id}) {
				# &send("Lost client $client_id\n");
				closeClient($id, $h);
				next;
			}
			if ($mask & POLLOUT) {
				$s = $outbufs{$id};
				$n = $h->syswrite($s);
				if (defined $n) {
					if ($n >= length($s)) {
						delete $outbufs{$id};
						# now can accept more input
						$poll->mask($h => (POLLIN|POLLHUP));
					} else {
						substr($outbufs{$id}, 0, $n) = '';
					}
				} elsif(! $!{EAGAIN} && ! $!{EINTR}) {
					warn "write to client $id failed: $!";
					closeClient($id, $h);
					next;
				}
			}
			if ($mask & POLLIN) {
				$n = $h->sysread($s, 10000);
				if ($n == 0) {
					# &send("Lost client $client_id\n");
					closeClient($id, $h);
					next;
				} elsif ($n > 0) {
					$inbufs{$id} .= $s;
				} elsif(! $!{EAGAIN} && ! $!{EINTR}) {
					warn "read from client $id failed: $!";
					closeClient($id, $h);
					next;
				}
			}
			# The way this works, if there is no '\n' before EOF,
			# the last line won't be processed.
			# Also, the whole output for all the input will be buffered
			# before it can be sent.
			while($inbufs{$id} =~ s/^(.*)\n//) {
				my $line = $1;
				chomp $line;
				local $/ = "\r"; # take care of a possible CR-LF
				chomp $line;
				my @data = split(/,/, $line);
				my $lname = shift @data;
				my $label = $labels->{$lname};
				if (defined $label) {
					my $unit = $label->getUnit();
					confess "label '$lname' received from client $id has been cleared"
						unless defined $unit;
					eval {
						$unit->makeArrayCall($label, @data);
						$unit->drainFrame();
					};
					warn "input data error: $@\nfrom data: $line\n" if $@;
				} else {
					warn "unknown label '$lname' received from client $id: $line "
				}
			}
		}
	}
}

# The server start function that creates the server socket,
# remembers its auto-generated unique port, then forks and
# starts the main loop in the child process. The parent
# process then returns the pair (port number, child PID).
sub startServer # ($labels)
{
	my $labels = shift;

	my $srvsock = IO::Socket::INET->new(
		Proto => "tcp",
		LocalPort => 0,
		Listen => 10,
	) or confess "socket failed: $!";
	my $port = $srvsock->sockport() or confess "sockport failed: $!";
	my $pid = fork();
	confess "fork failed: $!" unless defined $pid;
	if ($pid) {
		# parent
		$srvsock->close();
	} else {
		# child
		&mainLoop($srvsock, $labels);
		exit(0);
	}
	return ($port, $pid);
}

#########################
# The common client that connects to the port, sends and receives data,
# and waits for the server to exit.

sub run # ($labels)
{
	my $labels = shift;

	my ($port, $pid) = startServer($labels);
	my $sock = IO::Socket::INET->new(
		Proto => "tcp",
		PeerAddr => "localhost",
		PeerPort => $port,
	) or confess "socket failed: $!";
	while(&readLine) {
		$sock->print($_);
		$sock->flush();
	}
	$sock->print("exit,OP_INSERT\n");
	$sock->flush();
	$sock->shutdown(1); # SHUT_WR
	while(<$sock>) {
		&send($_);
	}
	waitpid($pid, 0);
}

#########################
# Common Triceps types.

# The basic table type to be used as template argument.
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
# A basic manual test of echo server.

if (0) {
	my $uEcho = Triceps::Unit->new("uEcho");
	my $lbEcho = $uEcho->makeLabel($rtTrade, "echo", undef, sub {
		&outCurBuf($_[1]->printP() . "\n");
	});
	my $lbEcho2 = $uEcho->makeLabel($rtTrade, "echo2", undef, sub {
		&outCurBuf(join(",", "echo", &Triceps::opcodeString($_[1]->getOpcode()),
			$_[1]->getRow()->toArray()) . "\n");
	});
	my $lbExit = $uEcho->makeLabel($rtTrade, "exit", undef, sub {
		$srv_exit = 1;
	});

	my %dispatch;
	$dispatch{"echo"} = $lbEcho;
	$dispatch{"echo2"} = $lbEcho2;
	$dispatch{"exit"} = $lbExit;

	my ($port, $pid) = &startServer(\%dispatch);
	print STDERR "port=$port pid=$pid\n";
	waitpid($pid, 0);
	exit(0);
}

#########################
# Module for server control.
package ServerHelpers;
use Carp;

# Exiting the server.
sub makeExitLabel # ($unit, $name)
{
	my $unit = shift;
	my $name = shift;
	return $unit->makeLabel($unit->getEmptyRowType(), $name, undef, sub {
		$srv_exit = 1;
	});
}

# Sending of rows to the server output.
sub makeServerOutLabel # ($fromLabel)
{
	my $fromLabel = shift;
	my $unit = $fromLabel->getUnit();
	my $fromName = $fromLabel->getName();
	my $lbOut = $unit->makeLabel($fromLabel->getType(), 
		$fromName . ".serverOut", undef, sub {
			&main::outCurBuf(join(",", $fromName, 
				&Triceps::opcodeString($_[1]->getOpcode()),
				$_[1]->getRow()->toArray()) . "\n");
		});
	$fromLabel->chain($lbOut) or confess "$!";
	return $lbOut;
}


#########################
# Module for querying the table, version 1: no conditions.

package Query1;

sub new # ($class, $table, $name)
{
	my $class = shift;
	my $table = shift;
	my $name = shift;

	my $unit = $table->getUnit();
	my $rt = $table->getRowType();

	my $self = {};
	$self->{unit} = $unit;
	$self->{name} = $name;
	$self->{table} = $table;
	$self->{inLabel} = $unit->makeLabel($rt, $name . ".in", undef, sub {
		# This version ignores the row contents, just dumps the table.
		my ($label, $rop, $self) = @_;
		my $rh = $self->{table}->begin();
		for (; !$rh->isNull(); $rh = $rh->next()) {
			$self->{unit}->call(
				$self->{outLabel}->makeRowop("OP_INSERT", $rh->getRow()));
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{outLabel}, "OP_NOP");
	}, $self);
	$self->{outLabel} = $unit->makeDummyLabel($rt, $name . ".out");
	
	bless $self, $class;
	return $self;
}

sub getInputLabel # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

sub getOutputLabel # ($self)
{
	my $self = shift;
	return $self->{outLabel};
}

sub getName # ($self)
{
	my $self = shift;
	return $self->{name};
}

package main;

#########################
# Server with module version 1.

sub runQuery1
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query1->new($tWindow, "qWindow");
my $srvout = &ServerHelpers::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

# the same input and result gets reused mutiple times
my @inputQuery1 = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"qWindow,OP_INSERT\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"qWindow,OP_INSERT\n",
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

@input = @inputQuery1;
$result = undef;
&runQuery1();
#print $result;
ok($result, $expectQuery1);

#########################
# Module for querying the table, version 2: including the table.

package TableQuery2;
use Carp;

sub new # ($class, $unit, $tabType, $name)
{
	my $class = shift;
	my $unit = shift;
	my $tabType = shift;
	my $name = shift;

	my $table = $unit->makeTable($tabType, "EM_CALL", $name)
		or confess "Query2 table creation failed: $!";
	my $rt = $table->getRowType();

	my $self = {};
	$self->{unit} = $unit;
	$self->{name} = $name;
	$self->{table} = $table;
	$self->{qLabel} = $unit->makeLabel($rt, $name . ".query", undef, sub {
		# This version ignores the row contents, just dumps the table.
		my ($label, $rop, $self) = @_;
		my $rh = $self->{table}->begin();
		for (; !$rh->isNull(); $rh = $rh->next()) {
			$self->{unit}->call(
				$self->{resLabel}->makeRowop("OP_INSERT", $rh->getRow()));
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{resLabel}, "OP_NOP");
	}, $self);
	$self->{resLabel} = $unit->makeDummyLabel($rt, $name . ".response");
	
	$self->{sendLabel} = &ServerHelpers::makeServerOutLabel($self->{resLabel});

	bless $self, $class;
	return $self;
}

sub getName # ($self)
{
	my $self = shift;
	return $self->{name};
}

sub getQueryLabel # ($self)
{
	my $self = shift;
	return $self->{qLabel};
}

sub getResponseLabel # ($self)
{
	my $self = shift;
	return $self->{resLabel};
}

sub getSendLabel # ($self)
{
	my $self = shift;
	return $self->{sendLabel};
}

sub getTable # ($self)
{
	my $self = shift;
	return $self->{table};
}

sub getInputLabel # ($self)
{
	my $self = shift;
	return $self->{table}->getInputLabel();
}

sub getOutputLabel # ($self)
{
	my $self = shift;
	return $self->{table}->getOutputLabel();
}

sub getPreLabel # ($self)
{
	my $self = shift;
	return $self->{table}->getPreLabel();
}

# add a factory to the Unit type
package Triceps::Unit;

sub makeTableQuery2 # ($self, $tabType, $name)
{
	return TableQuery2->new(@_);
}

package main;

#########################
# Server with module version 2.

sub runQuery2
{

my $uTrades = Triceps::Unit->new("uTrades");
my $window = $uTrades->makeTableQuery2($ttWindow, "window");

my %dispatch;
$dispatch{$window->getName()} = $window->getInputLabel();
$dispatch{$window->getQueryLabel()->getName()} = $window->getQueryLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = (
	"window,OP_INSERT,1,AAA,10,10\n",
	"window,OP_INSERT,3,AAA,20,20\n",
	"window.query,OP_INSERT\n",
	"window,OP_INSERT,5,AAA,30,30\n",
	"window.query,OP_INSERT\n",
);
$result = undef;
&runQuery2();
#print $result;
ok($result, 
'> window,OP_INSERT,1,AAA,10,10
> window,OP_INSERT,3,AAA,20,20
> window.query,OP_INSERT
> window,OP_INSERT,5,AAA,30,30
> window.query,OP_INSERT
window.response,OP_INSERT,1,AAA,10,10
window.response,OP_INSERT,3,AAA,20,20
window.response,OP_NOP,,,,
window.response,OP_INSERT,3,AAA,20,20
window.response,OP_INSERT,5,AAA,30,30
window.response,OP_NOP,,,,
');

#########################
# Module for querying the table, version 3: with options.

package Query3;

sub new # ($class, $optionName => $optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		table => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
	}, @_);
	
	my $name = $self->{name};

	my $table = $self->{table};
	my $unit = $table->getUnit();
	my $rt = $table->getRowType();

	$self->{unit} = $unit;
	$self->{name} = $name;
	$self->{inLabel} = $unit->makeLabel($rt, $name . ".in", undef, sub {
		# This version ignores the row contents, just dumps the table.
		my ($label, $rop, $self) = @_;
		my $rh = $self->{table}->begin();
		for (; !$rh->isNull(); $rh = $rh->next()) {
			$self->{unit}->call(
				$self->{outLabel}->makeRowop("OP_INSERT", $rh->getRow()));
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{outLabel}, "OP_NOP");
	}, $self);
	$self->{outLabel} = $unit->makeDummyLabel($rt, $name . ".out");
	
	bless $self, $class;
	return $self;
}

sub getInputLabel # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

sub getOutputLabel # ($self)
{
	my $self = shift;
	return $self->{outLabel};
}

sub getName # ($self)
{
	my $self = shift;
	return $self->{name};
}

package main;

#########################
# Server with module version 3.

sub runQuery3
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query3->new(table => $tWindow, name => "qWindow");
my $srvout = &ServerHelpers::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = @inputQuery1;
$result = undef;
&runQuery3();
#print $result;
ok($result, $expectQuery1);

#########################
# Module for querying the table, version 4: with fields for querying, interpreted.

package Query4;
use Carp;

sub new # ($class, $optionName => $optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		table => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
		fields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
	}, @_);
	
	my $name = $self->{name};

	my $table = $self->{table};
	my $unit = $table->getUnit();
	my $rt = $table->getRowType();

	my $fields = $self->{fields};
	if (defined $fields) {
		my %rtdef = $rt->getdef();
		foreach my $f (@$fields) {
			my $t = $rtdef{$f};
			confess "$class::new: unknown field '$f', the row type is:\n"
					. $rt->print() . " "
				unless defined $t;
		}
	}

	$self->{unit} = $unit;
	$self->{name} = $name;
	$self->{inLabel} = $unit->makeLabel($rt, $name . ".in", undef, sub {
		my ($label, $rop, $self) = @_;
		my $query = $rop->getRow();
		my $cmp = $self->{compare};
		my $rh = $self->{table}->begin();
		ITER: for (; !$rh->isNull(); $rh = $rh->next()) {
			if (defined $self->{fields}) {
				my $data = $rh->getRow();
				my %rtdef = $self->{table}->getRowType()->getdef();
				foreach my $f (@{$self->{fields}}) {
					my $v = $query->get($f);
					# Since the simplified CSV parsing in the mainLoop() provides
					# no easy way to send NULLs, consider any empty or 0 value
					# in the query row equivalent to NULLs.
					if ($v 
					&& (&Triceps::Fields::isStringType($rtdef{$f})
						? $query->get($f) ne $data->get($f)
						: $query->get($f) != $data->get($f)
						)
					) {
						next ITER;
					}
				}
			}
			$self->{unit}->call(
				$self->{outLabel}->makeRowop("OP_INSERT", $rh->getRow()));
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{outLabel}, "OP_NOP");
	}, $self);
	$self->{outLabel} = $unit->makeDummyLabel($rt, $name . ".out");
	
	bless $self, $class;
	return $self;
}

sub getInputLabel # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

sub getOutputLabel # ($self)
{
	my $self = shift;
	return $self->{outLabel};
}

sub getName # ($self)
{
	my $self = shift;
	return $self->{name};
}

package main;

#########################
# Server with module version 4.

sub runQuery4
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $cmpcode;
my $query = Query4->new(table => $tWindow, name => "qWindow",
	fields => ["symbol", "price"]);
my $srvout = &ServerHelpers::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"tWindow,OP_INSERT,4,BBB,20,20\n",
	"qWindow,OP_INSERT\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"qWindow,OP_INSERT,5,AAA,0,0\n",
	"qWindow,OP_INSERT,0,,20,0\n",
);
$result = undef;
&runQuery4();
#print $result;
ok($result, 
'> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> tWindow,OP_INSERT,4,BBB,20,20
> qWindow,OP_INSERT
> tWindow,OP_INSERT,5,AAA,30,30
> qWindow,OP_INSERT,5,AAA,0,0
> qWindow,OP_INSERT,0,,20,0
qWindow.out,OP_INSERT,1,AAA,10,10
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,4,BBB,20,20
qWindow.out,OP_NOP,,,,
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,5,AAA,30,30
qWindow.out,OP_NOP,,,,
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,4,BBB,20,20
qWindow.out,OP_NOP,,,,
');

#########################
# Server with module version 4, used with no query fields.

sub runQuery4a
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query4->new(table => $tWindow, name => "qWindow");
my $srvout = &ServerHelpers::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"qWindow,OP_INSERT\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"qWindow,OP_INSERT\n",
);
$result = undef;
&runQuery4a();
#print $result;
ok($result, 
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
');

#########################
# Module for querying the table, version 5: with fields for querying, compiled.

package Query5;
use Carp;

sub new # ($class, $optionName => $optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		table => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
		fields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
		saveCodeTo => [ undef, \&Triceps::Opt::ck_refscalar ],
	}, @_);
	
	my $name = $self->{name};

	my $table = $self->{table};
	my $unit = $table->getUnit();
	my $rt = $table->getRowType();

	my $fields = $self->{fields};
	if (defined $fields) {
		my %rtdef = $rt->getdef();

		# Generate the code of the comparison function by the fields.
		# Since the simplified CSV parsing in the mainLoop() provides
		# no easy way to send NULLs, consider any empty or 0 value
		# in the query row equivalent to NULLs.
		my $gencmp = '
			sub # ($query, $data)
			{
				use strict;
				my ($query, $data) = @_;';
		foreach my $f (@$fields) {
			my $t = $rtdef{$f};
			confess "$class::new: unknown field '$f', the row type is:\n"
					. $rt->print() . " "
				unless defined $t;
			$gencmp .= '
				my $v = $query->get("' . quotemeta($f) . '");
				if ($v) {';
			if (&Triceps::Fields::isStringType($t)) {
				$gencmp .= '
					return 0 if ($v ne $data->get("' . quotemeta($f) . '"));';
			} else {
				$gencmp .= '
					return 0 if ($v != $data->get("' . quotemeta($f) . '"));';
			}
			$gencmp .= '
				}';
		}
		$gencmp .= '
				return 1; # all succeeded
			}';

		${$self->{saveCodeTo}} = $gencmp if (defined($self->{saveCodeTo}));
		$self->{compare} = eval $gencmp;
		confess("Internal error: $class failed to compile the comparator:\n$@\nfunction text:\n$gencmp ")
			if $@;
	}

	$self->{unit} = $unit;
	$self->{name} = $name;
	$self->{inLabel} = $unit->makeLabel($rt, $name . ".in", undef, sub {
		my ($label, $rop, $self) = @_;
		my $query = $rop->getRow();
		my $cmp = $self->{compare};
		my $rh = $self->{table}->begin();
		for (; !$rh->isNull(); $rh = $rh->next()) {
			if (!defined $cmp || &$cmp($query, $rh->getRow())) {
				$self->{unit}->call(
					$self->{outLabel}->makeRowop("OP_INSERT", $rh->getRow()));
			}
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{outLabel}, "OP_NOP");
	}, $self);
	$self->{outLabel} = $unit->makeDummyLabel($rt, $name . ".out");
	
	bless $self, $class;
	return $self;
}

sub getInputLabel # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

sub getOutputLabel # ($self)
{
	my $self = shift;
	return $self->{outLabel};
}

sub getName # ($self)
{
	my $self = shift;
	return $self->{name};
}

package main;

#########################
# Server with module version 5.

sub runQuery5
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $cmpcode;
my $query = Query5->new(table => $tWindow, name => "qWindow",
	fields => ["symbol", "price"], saveCodeTo => \$cmpcode );
# as a demonstration
&send("Code:\n$cmpcode\n");
my $srvout = &ServerHelpers::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"tWindow,OP_INSERT,4,BBB,20,20\n",
	"qWindow,OP_INSERT\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"qWindow,OP_INSERT,5,AAA,0,0\n",
	"qWindow,OP_INSERT,0,,20,0\n",
);
$result = undef;
&runQuery5();
#print $result;
ok($result, 
'Code:

			sub # ($query, $data)
			{
				use strict;
				my ($query, $data) = @_;
				my $v = $query->get("symbol");
				if ($v) {
					return 0 if ($v ne $data->get("symbol"));
				}
				my $v = $query->get("price");
				if ($v) {
					return 0 if ($v != $data->get("price"));
				}
				return 1; # all succeeded
			}
> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> tWindow,OP_INSERT,4,BBB,20,20
> qWindow,OP_INSERT
> tWindow,OP_INSERT,5,AAA,30,30
> qWindow,OP_INSERT,5,AAA,0,0
> qWindow,OP_INSERT,0,,20,0
qWindow.out,OP_INSERT,1,AAA,10,10
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,4,BBB,20,20
qWindow.out,OP_NOP,,,,
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,5,AAA,30,30
qWindow.out,OP_NOP,,,,
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,4,BBB,20,20
qWindow.out,OP_NOP,,,,
');

#########################
# Server with module version 5, used with no query fields.

sub runQuery5a
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query5->new(table => $tWindow, name => "qWindow");
my $srvout = &ServerHelpers::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"qWindow,OP_INSERT\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"qWindow,OP_INSERT\n",
);
$result = undef;
&runQuery5a();
#print $result;
ok($result, 
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
');

#########################
# Module for querying the table, version 6: with query fields auto-determined.

package Query6;
use Carp;

sub new # ($class, $optionName => $optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		table => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
	}, @_);
	
	my $name = $self->{name};

	my $table = $self->{table};
	my $unit = $table->getUnit();
	my $rt = $table->getRowType();

	$self->{unit} = $unit;
	$self->{name} = $name;
	$self->{inLabel} = $unit->makeLabel($rt, $name . ".in", undef, sub {
		my ($label, $rop, $self) = @_;
		my $query = $rop->getRow();
		my $cmp = $self->genComparison($query);
		my $rh = $self->{table}->begin();
		for (; !$rh->isNull(); $rh = $rh->next()) {
			if (&$cmp($query, $rh->getRow())) {
				$self->{unit}->call(
					$self->{outLabel}->makeRowop("OP_INSERT", $rh->getRow()));
			}
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{outLabel}, "OP_NOP");
	}, $self);
	$self->{outLabel} = $unit->makeDummyLabel($rt, $name . ".out");
	
	bless $self, $class;
	return $self;
}

# Generate the comparison function on the fly from the fields in the
# query row.
# Since the simplified CSV parsing in the mainLoop() provides
# no easy way to send NULLs, consider any empty or 0 value
# in the query row equivalent to NULLs.
sub genComparison # ($self, $query)
{
	my $self = shift;
	my $query = shift;

	my %qhash = $query->toHash();
	my %rtdef = $self->{table}->getRowType()->getdef();
	my ($f, $v);

	my $gencmp = '
			sub # ($query, $data)
			{
				use strict;';

	while (($f, $v) = each %qhash) {
		next unless($v);
		my $t = $rtdef{$f};

		if (&Triceps::Fields::isStringType($t)) {
			$gencmp .= '
				return 0 if ($_[0]->get("' . quotemeta($f) . '")
					ne $_[1]->get("' . quotemeta($f) . '"));';
		} else {
			$gencmp .= '
				return 0 if ($_[0]->get("' . quotemeta($f) . '")
					!= $_[1]->get("' . quotemeta($f) . '"));';
		}
	}
	$gencmp .= '
				return 1; # all succeeded
			}';

	my $compare = eval $gencmp;
	confess("Internal error: Query '" . $self->{name} 
			. "' failed to compile the comparator:\n$@\nfunction text:\n$gencmp ")
		if $@;

	# for debugging
	&main::outCurBuf("Compiled comparator:\n$gencmp\n");

	return $compare;
}

sub getInputLabel # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

sub getOutputLabel # ($self)
{
	my $self = shift;
	return $self->{outLabel};
}

sub getName # ($self)
{
	my $self = shift;
	return $self->{name};
}

package main;

#########################
# Server with module version 6.

sub runQuery6
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query6->new(table => $tWindow, name => "qWindow",);
my $srvout = &ServerHelpers::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = (
	"tWindow,OP_INSERT,1,AAA,10,10\n",
	"tWindow,OP_INSERT,3,AAA,20,20\n",
	"tWindow,OP_INSERT,4,BBB,20,20\n",
	"qWindow,OP_INSERT\n",
	"tWindow,OP_INSERT,5,AAA,30,30\n",
	"qWindow,OP_INSERT,5,AAA,0,0\n",
	"qWindow,OP_INSERT,0,,20,0\n",
);
$result = undef;
&runQuery6();
#print $result;
ok($result, 
'> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> tWindow,OP_INSERT,4,BBB,20,20
> qWindow,OP_INSERT
> tWindow,OP_INSERT,5,AAA,30,30
> qWindow,OP_INSERT,5,AAA,0,0
> qWindow,OP_INSERT,0,,20,0
Compiled comparator:

			sub # ($query, $data)
			{
				use strict;
				return 1; # all succeeded
			}
qWindow.out,OP_INSERT,1,AAA,10,10
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,4,BBB,20,20
qWindow.out,OP_NOP,,,,
Compiled comparator:

			sub # ($query, $data)
			{
				use strict;
				return 0 if ($_[0]->get("symbol")
					ne $_[1]->get("symbol"));
				return 0 if ($_[0]->get("id")
					!= $_[1]->get("id"));
				return 1; # all succeeded
			}
qWindow.out,OP_INSERT,5,AAA,30,30
qWindow.out,OP_NOP,,,,
Compiled comparator:

			sub # ($query, $data)
			{
				use strict;
				return 0 if ($_[0]->get("price")
					!= $_[1]->get("price"));
				return 1; # all succeeded
			}
qWindow.out,OP_INSERT,3,AAA,20,20
qWindow.out,OP_INSERT,4,BBB,20,20
qWindow.out,OP_NOP,,,,
');

#########################
# Module for querying the table, version 7: with projection in the result.
# (based on version 3)

package Query7;

sub new # ($class, $optionName => $optionValue ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		table => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Table") } ],
		resultFields => [ undef, sub { &Triceps::Opt::ck_ref(@_, "ARRAY", ""); } ],
	}, @_);
	
	my $name = $self->{name};

	my $table = $self->{table};
	my $unit = $table->getUnit();
	my $rtIn = $table->getRowType();
	my $rtOut = $rtIn;

	if (defined $self->{resultFields}) {
		my @inFields = $rtIn->getFieldNames();
		my @pairs =  &Triceps::Fields::filterToPairs($class, \@inFields, $self->{resultFields});
		($rtOut, $self->{projectFunc}) = &Triceps::Fields::makeTranslation(
			rowTypes => [ $rtIn ],
			filterPairs => [ \@pairs ],
		);
	} else {
		$self->{projectFunc} = sub {
			return $_[0];
		}
	}

	$self->{unit} = $unit;
	$self->{name} = $name;
	$self->{inLabel} = $unit->makeLabel($rtIn, $name . ".in", undef, sub {
		# This version ignores the row contents, just dumps the table.
		my ($label, $rop, $self) = @_;
		my $rh = $self->{table}->begin();
		for (; !$rh->isNull(); $rh = $rh->next()) {
			$self->{unit}->call(
				$self->{outLabel}->makeRowop("OP_INSERT", 
					&{$self->{projectFunc}}($rh->getRow())));
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{outLabel}, "OP_NOP");
	}, $self);
	$self->{outLabel} = $unit->makeDummyLabel($rtOut, $name . ".out");
	
	bless $self, $class;
	return $self;
}

sub getInputLabel # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

sub getOutputLabel # ($self)
{
	my $self = shift;
	return $self->{outLabel};
}

sub getName # ($self)
{
	my $self = shift;
	return $self->{name};
}

package main;

#########################
# Server with module version 7.

sub runQuery7
{


my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query7->new(table => $tWindow, name => "qWindow",
	resultFields => [ '!id', 'size/lot_$&', '.*' ],
);
# print in the tokenized format
my $srvout = $uTrades->makeLabel($query->getOutputLabel()->getType(), 
	$query->getOutputLabel()->getName() . ".serverOut", undef, sub {
		&main::outCurBuf($_[1]->printP() . "\n");
	});
$query->getOutputLabel()->chain($srvout) or confess "$!";

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);

};

@input = @inputQuery1;
$result = undef;
&runQuery7();
#print $result;
ok($result, 
'> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> qWindow,OP_INSERT
> tWindow,OP_INSERT,5,AAA,30,30
> qWindow,OP_INSERT
qWindow.out OP_INSERT symbol="AAA" price="10" lot_size="10" 
qWindow.out OP_INSERT symbol="AAA" price="20" lot_size="20" 
qWindow.out OP_NOP 
qWindow.out OP_INSERT symbol="AAA" price="20" lot_size="20" 
qWindow.out OP_INSERT symbol="AAA" price="30" lot_size="30" 
qWindow.out OP_NOP 
');

#########################
# example of Triceps::Opt::handleUnitTypeLabel()

package ServerOutput;
use Carp;

# Sending of rows to the server output.
sub new # ($class, $option => $value, ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, undef ],
		unit => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
		rowType => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::RowType") } ],
		fromLabel => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Label") } ],
	}, @_);

	&Triceps::Opt::handleUnitTypeLabel("$class::new",
		unit => \$self->{unit},
		rowType => \$self->{rowType},
		fromLabel => \$self->{fromLabel}
	);
	my $fromLabel = $self->{fromLabel};
	
	if (!defined $self->{name}) {
		confess "$class::new: must specify at least one of the options name and fromLabel"
			unless (defined $self->{fromLabel});
		$self->{name} = $fromLabel->getName() . ".serverOut";
	}

	my $lb = $self->{unit}->makeLabel($self->{rowType}, 
		$self->{name}, undef, sub {
			&main::outCurBuf(join(",", 
				$fromLabel? $fromLabel->getName() : $self->{name},
				&Triceps::opcodeString($_[1]->getOpcode()),
				$_[1]->getRow()->toArray()) . "\n");
		}, $self # $self is not used in the function but used for cleaning
	);
	$self->{inLabel} = $lb;
	if (defined $fromLabel) {
		$fromLabel->chain($lb) or confess "$!";
	}

	bless $self, $class;
	return $self;
}

sub getInputLabel() # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

package main;

#########################
# Example with ServerOutput attached to label, using Query1.

sub runServerOutputFromLabel
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query1->new($tWindow, "qWindow");
my $srvout = ServerOutput->new(fromLabel => $query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = @inputQuery1;
$result = undef;
&runServerOutputFromLabel();
#print $result;
ok($result, $expectQuery1);

#########################
# Example with ServerOutput created independently, using Query1.

sub runServerOutputFromRowType
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query1->new($tWindow, "qWindow");
my $srvout = ServerOutput->new(
	name => "out",
	unit => $uTrades,
	rowType => $tWindow->getRowType(),
);
$query->getOutputLabel()->chain($srvout->getInputLabel())
	or confess "$!";

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = @inputQuery1;
$result = undef;
&runServerOutputFromRowType();
#print $result;
ok($result,
'> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> qWindow,OP_INSERT
> tWindow,OP_INSERT,5,AAA,30,30
> qWindow,OP_INSERT
out,OP_INSERT,1,AAA,10,10
out,OP_INSERT,3,AAA,20,20
out,OP_NOP,,,,
out,OP_INSERT,3,AAA,20,20
out,OP_INSERT,5,AAA,30,30
out,OP_NOP,,,,
');

#########################
# example of Triceps::Opt::checkMutuallyExclusive()

package ServerOutput2;
use Carp;

# Sending of rows to the server output.
sub new # ($class, $option => $value, ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		name => [ undef, undef ],
		unit => [ undef, sub { &Triceps::Opt::ck_mandatory; &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
		rowType => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::RowType") } ],
		fromLabel => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Label") } ],
	}, @_);

	my $fromLabel = $self->{fromLabel};
	if (&Triceps::Opt::checkMutuallyExclusive("$class::new", 1,
			rowType => $self->{rowType},
			fromLabel => $self->{fromLabel}
		) eq "fromLabel"
	) {
		$self->{rowType} = $fromLabel->getRowType();
	}
	
	if (!defined $self->{name}) {
		confess "$class::new: must specify at least one of the options name and fromLabel"
			unless (defined $self->{fromLabel});
		$self->{name} = $fromLabel->getName() . ".serverOut";
	}

	my $lb = $self->{unit}->makeLabel($self->{rowType}, 
		$self->{name}, undef, sub {
			&main::outCurBuf(join(",", 
				$fromLabel? $fromLabel->getName() : $self->{name},
				&Triceps::opcodeString($_[1]->getOpcode()),
				$_[1]->getRow()->toArray()) . "\n");
		}, $self # $self is not used in the function but used for cleaning
	);
	$self->{inLabel} = $lb;
	if (defined $fromLabel) {
		$fromLabel->chain($lb) or confess "$!";
	}

	bless $self, $class;
	return $self;
}

sub getInputLabel() # ($self)
{
	my $self = shift;
	return $self->{inLabel};
}

package main;

#########################
# Example with ServerOutput attached to label, using Query1.

sub runServerOutput2FromLabel
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query1->new($tWindow, "qWindow");
my $srvout = ServerOutput2->new(
	unit => $uTrades,
	fromLabel => $query->getOutputLabel()
);

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = @inputQuery1;
$result = undef;
&runServerOutput2FromLabel();
#print $result;
ok($result, $expectQuery1);

#########################
# Example with ServerOutput created independently, using Query1.

sub runServerOutput2FromRowType
{

my $uTrades = Triceps::Unit->new("uTrades");
my $tWindow = $uTrades->makeTable($ttWindow, "EM_CALL", "tWindow")
	or confess "$!";
my $query = Query1->new($tWindow, "qWindow");
my $srvout = ServerOutput2->new(
	name => "out",
	unit => $uTrades,
	rowType => $tWindow->getRowType(),
);
$query->getOutputLabel()->chain($srvout->getInputLabel())
	or confess "$!";

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ServerHelpers::makeExitLabel($uTrades, "exit");

run(\%dispatch);
};

@input = @inputQuery1;
$result = undef;
&runServerOutput2FromRowType();
#print $result;
ok($result,
'> tWindow,OP_INSERT,1,AAA,10,10
> tWindow,OP_INSERT,3,AAA,20,20
> qWindow,OP_INSERT
> tWindow,OP_INSERT,5,AAA,30,30
> qWindow,OP_INSERT
out,OP_INSERT,1,AAA,10,10
out,OP_INSERT,3,AAA,20,20
out,OP_NOP,,,,
out,OP_INSERT,3,AAA,20,20
out,OP_INSERT,5,AAA,30,30
out,OP_NOP,,,,
');

