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
BEGIN { plan tests => 1 };
use Triceps;
use Carp;
use Errno qw(EINTR EAGAIN);
use IO::Poll qw(POLLIN POLLOUT POLLHUP);
use IO::Socket;
use IO::Socket::INET;
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

# writing to the output buffers
sub outBuf # ($id, $string)
{
	my $id = shift;
	my $line = shift;
	#&sendX("XXX writing1 to $id: $line\n");
	$outbufs{$id} .= $line;
	#&sendX("XXX writing to $id: ", $outbufs{$id}, "\n");
	# If there is anything to write on a buffer, stop reading from it.
	$poll->mask($clients{$id} => (POLLHUP|POLLOUT));
}

sub outCurBuf # ($string)
{
	#&sendX("XXX writing cur $cur_cli: ", $_[0], "\n");
	outBuf($cur_cli, @_);
}

sub closeClient # ($id, $h)
{
	my $id = shift;
	my $h = shift;
	$poll->mask($h, 0);
	$h->close();
	delete $clients{$id}; # OK perl Perl manual even when iterating
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

	while(1) {
		my $r = $poll->poll();
		confess "poll failed: $!" if ($r < 0 && ! $!{EAGAIN} && ! $!{EINTR});

		if ($poll->events($srvsock)) {
			while(1) {
				my $client = $srvsock->accept();
				if (defined $client) {
					$client->blocking(0);
					$clients{++$client_id} = $client;
					&sendX("Accepted client $client_id\n");
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
			if ($mask & POLLHUP) {
				&sendX("Lost client $client_id\n");
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
					confess "write to client $id failed: $!";
				}
			}
			if ($mask & POLLIN) {
				$n = $h->sysread($s, 1000);
				if ($n == 0) {
					&sendX("Lost client $client_id\n");
					closeClient($id, $h);
					next;
				} elsif ($n > 0) {
					$inbufs{$id} .= $s;
				} elsif(! $!{EAGAIN} && ! $!{EINTR}) {
					confess "read from client $id failed: $!";
				}
			}
			# The way this works, if there is no '\n' before EOF,
			# the last line won't be processed.
			# Also, the whole output for all the input will be buffered
			# before it can be sent.
			#&sendX("XXX input buffer for $id: ", $inbufs{$id}, "\n");
			while($inbufs{$id} =~ s/^(.*)\n//) {
				my $line = $1;
				#&sendX("XXX line for $id: $line\n");
				if (0) {
					# for debugging, an echo server
					&outCurBuf("$line\n");
				} else {
					chomp $line;
					local $/ = "\r"; # take care of a possible CR-LF
					chomp $line;
					my @data = split(/,/, $line);
					my $lname = shift @data;
					my $label = $labels->{$lname};
					confess "unknown label '$label' received from client $id: $line "
						unless defined $label;
					my $unit = $label->getUnit();
					confess "label '$label' received from client $id has been cleared"
						unless defined $unit;
					$unit->makeArrayCall($label, @data);
					$unit->drainFrame();
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
# A test of echo server.

if (0) {
	my $uEcho = Triceps::Unit->new("uEcho");
	my $lbEcho = $uEcho->makeLabel($rtTrade, "echo", undef, sub {
		&outCurBuf($_[1]->printP() . "\n");
	});

	my %dispatch;
	$dispatch{"echo"} = $lbEcho;

	my ($port, $pid) = &startServer(\%dispatch);
	print STDERR "port=$port pid=$pid\n";
	exit(0);
}

