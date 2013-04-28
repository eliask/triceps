#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A simple multithreaded client for the send-expect sequences.
# It has been written for the unit testing of the server examples
# but can have other initeresting uses.
# It's of very decent quality but needs the official tests.

use strict;

##############################
# the client for automated testing

package Triceps::X::ThreadedClient;

sub CLONE_SKIP { 1; }

our $VERSION = 'v1.0.1';

use Carp;
use IO::Socket;
use IO::Socket::INET;
use Triceps;

# The client app has the following threads:
# * Global/main thread: controls the execution, sends the requests to the
#   other threads, eventually collects all the inputs from the sockets.
# * Per-client threads, as described below
# * Collector thread that collects the inputs from the client threads
#   and waits for patterns in it; eventually passes the collected
#   inputs to the main thread.

# Each client consists of the following threads:
# * writer: writes to the socket
# * reader: reads from the socket, passes data to the collector thread

# The collector thread that handles the data received from the clients.
#
# Options:
#
# port => $port
# Server port number, to which the clients will connect.
sub collectorT # (@opts)
{
	my $myname = "Triceps::X::ThreadedClient::collectorT";
	my $opts = {};
	&Triceps::Opt::parse($myname, $opts, {@Triceps::Triead::opts,
		port => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_;
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $tname = $opts->{thread};
	my $unit = $owner->unit();

	# a message read from or to be written to a client's connection
	my $rtMsg = Triceps::RowType->new(
		client => "string", # client name
		text => "string", # text of the message
	) or confess "$!";

	# a control message from the global thread
	my $rtCtl = Triceps::RowType->new(
		cmd => "string", # the command to execute
		client => "string", # client on which the command applies
		arg => "string", # the command argument
	) or confess "$!";

	my $faSend = $owner->makeNexus( # messages to be sent to the client writers
		name => "send",
		labels => [
			msg => $rtMsg, # data messages
			close => $rtMsg, # request to shut down either side of the socket (text is ignored)
		],
		import => "writer",
	);
	my $faRecv = $owner->makeNexus( # messages to received from the client readers
		name => "receive",
		labels => [
			msg => $rtMsg,
		],
		import => "reader",
	);

	my $faCtl = $owner->makeNexus( # control messages to collector
		name => "ctl",
		labels => [
			msg => $rtCtl,
		],
		import => "reader",
	);
	my $faReply = $owner->makeNexus( # replies to the control messages from the collector
		name => "reply",
		labels => [
			msg => $rtCtl,
			done => $rtCtl, # marks the end of multi-message responses (the contents of the row is ignored)
		],
		reverse => 1,
		import => "writer",
	);

	my $lbRepMsg = $faReply->getLabel("msg");
	my $lbRepDone = $faReply->getLabel("done");

	#### state of the clients ###

	my %recv; # the received data, keyed by the client
	my %newrecv; # the latest received data, keyed by the client;
		# this is the data since the last match requested was found,
		# gets appended to the end of %recv and cleared after that
	my %pattern; # the pattern to match in the received data, keyed by the client

	#### local functions ###

	# Move the client's data from %newrecv to %recv
	my $catrecv = sub { # ($client)
		my $client = shift;
		if (exists $newrecv{$client}) {
			$recv{$client} .= $newrecv{$client};
			delete $newrecv{$client};
		}
	};

	# Check if the client's new data matches its pattern, and if so then
	# move its data to %recv and sent a reply to the global thread.
	my $checkPattern = sub { # ($client)
		my $client = shift;
		if (exists $pattern{$client} && exists $newrecv{$client}) {
			my $p = $pattern{$client};
			if ($newrecv{$client} =~ /$p/) {
				my $text = $newrecv{$client};
				&$catrecv($client);
				delete $pattern{$client};
				$unit->makeHashCall($lbRepMsg, "OP_INSERT", 
					cmd => "expect",
					client => $client,
					text => $text,
				);
			}
		}
	};

	### rest of the logic ###

	$faRecv->getLabel("msg")->makeChained("lbRecv", undef, sub {
		my ($client, $text) = $_[1]->getRow()->toArray();
		$newrecv{$client} .= $text;
		&$checkPattern($client);
	});

	$faCtl->getLabel("msg")->makeChained("lbCtl", undef, sub {
		my ($cmd, $client, $arg) = $_[1]->getRow()->toArray();
		if ($cmd eq "expect") {
			# expact a certain pattern from a client
			$pattern{$client} = qr/$arg/m;
			&$checkPattern($client); # might be already received
		} elsif ($cmd eq "dump") {
			# dump the data received from all clients
			for my $client (keys(%newrecv)) {
				&$catrecv($client);
			}
			for my $client (sort(keys(%recv))) {
				$unit->makeHashCall($lbRepMsg, "OP_INSERT", 
					cmd => "dump",
					client => $client,
					arg => $recv{$client},
				);
			}
			$unit->makeHashCall($lbRepDone, "OP_INSERT", 
				cmd => "dump",
			);
		} else {
			confess "$myname: received an unknown command '$cmd'";
		}
	});

	$owner->readyReady();
	$owner->mainLoop();
}

# Thread that sends data to the socket.
#
# Options:
#
# client => $clientName
# Name of the client.
sub clientSendT # (@opts)
{
	my $myname = "Triceps::X::ThreadedClient::clientSendT";
	my $opts = {};
	&Triceps::Opt::parse($myname, $opts, {@Triceps::Triead::opts,
		client => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_;
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $unit = $owner->unit();
	my ($tsock, $sock) = $owner->trackDupSocket($opts->{client}, ">");

	my $faSend = $owner->importNexus(
		from => "collector/send",
		import => "reader",
	);

	$faSend->getLabel("msg")->makeChained("lbSend", undef, sub {
		my ($client, $text) = $_[1]->getRow()->toArray();
		if ($opts->{client} eq $client) {
			printOrShut($app, $opts->{fragment}, $sock, $text);
		}
	});
	$faSend->getLabel("close")->makeChained("lbClose", undef, sub {
		my ($client, $text) = $_[1]->getRow()->toArray();
		if ($opts->{client} eq $client) {
			if ($text eq "RD") {
				$sock->shutdown(0);
			} elsif ($text eq "WR") {
				$sock->shutdown(1);
			} elsif ($text eq "RDWR") {
				$sock->shutdown(2);
			} else {
				confess "$myname: unknown argument for close '$text'";
			}
		}
	});

	$owner->readyReady();
	$owner->mainLoop();
};

# Thread that receives data from the socket.
#
# Options:
#
# client => $clientName
# Name of the client.
sub clientRecvT # (@opts)
{
	my $myname = "Triceps::X::ThreadedClient::clientRecvT";
	my $opts = {};
	&Triceps::Opt::parse($myname, $opts, {@Triceps::Triead::opts,
		client => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_;
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $unit = $owner->unit();
	my ($tsock, $sock) = $owner->trackDupSocket($opts->{client}, "<");

	my $faRecv = $owner->importNexus(
		from => "collector/receive",
		import => "writer",
	);

	my $lbRecv = $faRecv->getLabel("msg");

	$owner->readyReady();

	while (<$sock>) {
		$unit->makeHashCall($lbRecv, "OP_INSERT", 
			client => $opts->{client},
			text => $_,
		);
		$owner->flushWriters();
	}
	# also explicitly mark the end of data
	$unit->makeHashCall($lbRecv, "OP_INSERT", 
		client => $opts->{client},
		text => "__EOF__",
	);
}

# The object is instantiated in the global/main thread.
#
# DOES NOT MARK THE MAIN THREAD AS READY.
#
# Options:
#
# owner => $TrieadOwner
# The thread owner wher this object is instantiated.
#
# port => $port
# Server port number, to which the clients will connect.
#
# debug => 0/1
# (optional) Enable the debugging printout of the protocol as it comes in.
# Default: 0.
#
sub new # ($class, @opts)
{
	my $myname = "Triceps::X::ThreadedClient::new";
	my $class = shift;
	my $self = {};
	&Triceps::Opt::parse($class, $self, {
		owner => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::TrieadOwner") } ],
		port => [ undef, \&Triceps::Opt::ck_mandatory ],
		debug => [ 0, undef ],
	}, @_);

	my $owner = $self->{owner};

	$self->{protocol} = ""; # protocol of all the data sent and expected

	# start the collector thread, it will define all the nexuses
	Triceps::Triead::start(
		app => $owner->app()->getName(),
		thread => "collector",
		main => \&collectorT,
		port => $self->{port},
	);

	# the sending nexus will be used to send directly to clients
	$self->{faSend} = $owner->importNexus(
		from => "collector/send",
		import => "writer",
	);
	# the control nexuses from the collector
	$self->{faCtl} = $owner->importNexus(
		from => "collector/ctl",
		import => "writer",
	);
	$self->{faReply} = $owner->importNexus(
		from => "collector/reply",
		import => "reader",
	);

	$self->{faReply}->getLabel("msg")->makeChained("lbReplyExpect", undef, sub {
		my ($cmd, $client, $arg) = $_[1]->getRow()->toArray();
		if ($cmd eq "expect") {
			my $ptext = $arg;
			$ptext =~ s/^/$client|/gm;
			$self->{protocol} .= $ptext;
			if ($self->{debug}) {
				print $ptext;
			}
			$self->{expectDone} = 1;
		}
	});

	bless $self, $class;
	return $self;
}

# Shut down the app on destruction.
sub DESTROY # ($self)
{
	my $myname = "Triceps::X::ThreadedClient::DESTROY";
	my $self = shift;
	$self->{owner}->app()->shutdown();
}

# Start the client connection and the threads for it.
# Waits for the connection setup to complete.
#
# @param client - the client name
sub startClient # ($self, $client)
{
	my $myname = "Triceps::X::ThreadedClient::startClient";
	my $self = shift;
	my $client = shift;

	my $owner = $self->{owner};
	my $app = $owner->app();

	my $sock = IO::Socket::INET->new(
		Proto => "tcp",
		PeerAddr => "localhost",
		PeerPort => $self->{port},
	) or confess "$myname: socket failed: $!";

	# the client threads will dup; the socket name must be the
	# same as the client name, as expected by the send/recv threads
	$app->storeFile($client, $sock);

	Triceps::Triead::start(
		app => $owner->app()->getName(),
		thread => "send_$client",
		fragment => "client_$client",
		main => \&clientSendT,
		client => $client,
	);

	Triceps::Triead::start(
		app => $owner->app()->getName(),
		thread => "recv_$client",
		fragment => "client_$client",
		main => \&clientRecvT,
		client => $client,
	);

	$owner->readyReady();
	$app->closeFd($client);
}

# Send data to a client.
#
# @param client - the client name
# @param text - the text to send
sub send # ($self, $client, $text)
{
	my $myname = "Triceps::X::ThreadedClient::send";
	my $self = shift;
	my $client = shift;
	my $text = shift;

	my $ptext = $text;
	$ptext =~ s/^/> $client|/gm;
	$self->{protocol} .= $ptext;
	if ($self->{debug}) {
		print $ptext;
	}

	my $owner = $self->{owner};
	$owner->unit()->makeHashCall($self->{faSend}->getLabel("msg"), "OP_INSERT",
		client => $client,
		text => $text,
	);
	$owner->flushWriters();
}

# Send a socket shutdown request to a client.
#
# @param client - the client name
# @param how - one of "RD", "WR", "RDWR"
sub sendClose # ($self, $client, $how)
{
	my $myname = "Triceps::X::ThreadedClient::sendClose";
	my $self = shift;
	my $client = shift;
	my $how = shift;

	my $owner = $self->{owner};
	$owner->unit()->makeHashCall($self->{faSend}->getLabel("close"), "OP_INSERT",
		client => $client,
		text => $how,
	);
	$owner->flushWriters();
}

# Expect data from a client.
#
# @param client - the client name
# @param pattern - string containing a regexp pattern to expect
sub expect # ($self, $client, $pattern)
{
	my $myname = "Triceps::X::ThreadedClient::expect";
	my $self = shift;
	my $client = shift;
	my $pattern = shift;

	my $owner = $self->{owner};

	$self->{expectDone} = 0;

	$owner->unit()->makeHashCall($self->{faCtl}->getLabel("msg"), "OP_INSERT",
		cmd => "expect",
		client => $client,
		arg => $pattern,
	);
	$owner->flushWriters();

	while(!$self->{expectDone}) {
		$owner->nextXtray();
	}
}

# Get the collected protocol.
# @return - the protocol text
sub protocol # ($self)
{
	my $self = shift;
	return $self->{protocol};
}

1;
