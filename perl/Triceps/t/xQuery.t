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
BEGIN { plan tests => 3 };
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
		Triceps::IndexType->newHashed(key => [ "symbol" ])
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
package ExitServer;
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
		$fromName . "serverOut", undef, sub {
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
				$self->{outLabel}->makeRowop("OP_INSERT", $rh->getRow()))
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
my $srvout = &ExitServer::makeServerOutLabel($query->getOutputLabel());

my %dispatch;
$dispatch{$tWindow->getName()} = $tWindow->getInputLabel();
$dispatch{$query->getName()} = $query->getInputLabel();
$dispatch{"exit"} = &ExitServer::makeExitLabel($uTrades, "exit");

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
&runQuery1();
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
				$self->{resLabel}->makeRowop("OP_INSERT", $rh->getRow()))
		}
		# The end is signaled by OP_NOP with empty fields.
		$self->{unit}->makeArrayCall($self->{resLabel}, "OP_NOP");
	}, $self);
	$self->{resLabel} = $unit->makeDummyLabel($rt, $name . ".response");
	
	$self->{sendLabel} = &ExitServer::makeServerOutLabel($self->{resLabel});

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

package main;

#########################
# Server with module version 2.

sub runQuery2
{

my $uTrades = Triceps::Unit->new("uTrades");
my $window = TableQuery2->new($uTrades, $ttWindow, "window");

my %dispatch;
$dispatch{$window->getName()} = $window->getInputLabel();
$dispatch{$window->getQueryLabel()->getName()} = $window->getQueryLabel();
$dispatch{"exit"} = &ExitServer::makeExitLabel($uTrades, "exit");

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
