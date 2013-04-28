#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The example of a chat with multithreading.

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 1 };
use strict;
use Triceps;
use Triceps::X::TestFeed qw(:all);
use Triceps::X::ThreadedServer qw(printOrShut);
use Carp;
ok(1); # If we made it this far, we're ok.

# exit 0; # XXX disable the logic

#########################

# Listener for connections.
# Extra options:
#
# socketName => $name
# The listening socket name in the App.
#
sub listenerT
{
	my $opts = {};
	&Triceps::Opt::parse("listenerT", $opts, {@Triceps::Triead::opts,
		socketName => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_;
	my $owner = $opts->{owner};

	my ($tsock, $sock) = $owner->trackGetSocket($opts->{socketName}, "+<");

	# a chat text message
	my $rtMsg = Triceps::RowType->new(
		topic => "string",
		msg => "string",
	) or confess "$!";

	# a control message between the reader and writer threads
	my $rtCtl = Triceps::RowType->new(
		cmd => "string", # the command to execute
		arg => "string", # the command argument
	) or confess "$!";

	$owner->makeNexus(
		name => "chat",
		labels => [
			msg => $rtMsg,
		],
		rowTypes => [
			ctl => $rtCtl,
		],
		import => "none",
	);

	$owner->readyReady();

	Triceps::X::ThreadedServer::listen(
		owner => $owner,
		socket => $sock,
		prefix => "cliconn",
		handler => \&chatSockReadT,
	);
}


# The socket reading side of the client connection.
sub chatSockReadT
{
	my $opts = {};
	&Triceps::Opt::parse("chatSockReadT", $opts, {@Triceps::Triead::opts,
		socketName => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_; # avoids a leak in threads module
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $unit = $owner->unit();
	my $tname = $opts->{thread};

	# only dup the socket, the writer thread will consume it
	my ($tsock, $sock) = $owner->trackDupSocket($opts->{socketName}, "<");

	# user messages will be sent here
	my $faChat = $owner->importNexus(
		from => "global/chat",
		import => "writer",
	);

	# control messages to the reader side will be sent here
	my $faCtl = $owner->makeNexus(
		name => "ctl",
		labels => [
			ctl => $faChat->impRowType("ctl"),
		],
		reverse => 1, # gives this nexus a high priority
		import => "writer",
	);

	$owner->markConstructed();

	Triceps::Triead::start(
		app => $opts->{app},
		thread => "$tname.rd",
		fragment => $opts->{fragment},
		main => \&chatSockWriteT,
		socketName => $opts->{socketName},
		ctlFrom => "$tname/ctl",
	);

	$owner->readyReady();

	my $lbChat = $faChat->getLabel("msg");
	my $lbCtl = $faCtl->getLabel("ctl");

	$unit->makeHashCall($lbCtl, "OP_INSERT", cmd => "print", arg => "!ready," . $opts->{fragment});
	$owner->flushWriters();

	while(<$sock>) {
		s/[\r\n]+$//;
		my @data = split(/,/);
		if ($data[0] eq "exit") {
			last; # a special case, handle in this thread
		} elsif ($data[0] eq "kill") {
			eval {$app->shutdownFragment($data[1]);};
			if ($@) {
				$unit->makeHashCall($lbCtl, "OP_INSERT", cmd => "print", arg => "!error,$@");
				$owner->flushWriters();
			}
		} elsif ($data[0] eq "shutdown") {
			$unit->makeHashCall($lbChat, "OP_INSERT", topic => "*", msg => "server shutting down");
			$owner->flushWriters();
			Triceps::AutoDrain::makeShared($owner);
			eval {$app->shutdown();};
		} elsif ($data[0] eq "publish") {
			$unit->makeHashCall($lbChat, "OP_INSERT", topic => $data[1], msg => $data[2]);
			$owner->flushWriters();
		} else {
			# this is not something you want to do in a real chat application
			# but it's cute for a demonstration
			$unit->makeHashCall($lbCtl, "OP_INSERT", cmd => $data[0], arg => $data[1]);
			$owner->flushWriters();
		}
	}

	{
		# let the data drain through
		my $drain = Triceps::AutoDrain::makeExclusive($owner);

		# send the notification - can do it because the drain is excluding itself
		$unit->makeHashCall($lbCtl, "OP_INSERT", cmd => "print", arg => "!exiting");
		$owner->flushWriters();

		$drain->wait(); # wait for the notification to drain

		$app->shutdownFragment($opts->{fragment});
	}

	$tsock->close(); # not strictly necessary
	print "XXX reader $tname exits\n";
}

# The socket writing side of the client connection.
sub chatSockWriteT
{
	my $opts = {};
	&Triceps::Opt::parse("chatSockWriteT", $opts, {@Triceps::Triead::opts,
		socketName => [ undef, \&Triceps::Opt::ck_mandatory ],
		ctlFrom => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_;
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $tname = $opts->{thread};

	my ($tsock, $sock) = $owner->trackGetSocket($opts->{socketName}, ">");

	my $faChat = $owner->importNexus(
		from => "global/chat",
		import => "reader",
	);

	my $faCtl = $owner->importNexus(
		from => $opts->{ctlFrom},
		import => "reader",
	);

	my %topics; # subscribed topics for this thread

	$faChat->getLabel("msg")->makeChained("lbMsg", undef, sub {
		my $row = $_[1]->getRow();
		my $topic = $row->get("topic");
		#printOrShut($app, $opts->{fragment}, $sock, "XXX got topic '$topic'\n");
		if ($topic eq "*" || exists $topics{$topic}) {
			printOrShut($app, $opts->{fragment}, $sock, $topic, ",", $row->get("msg"), "\n");
		}
	});

	$faCtl->getLabel("ctl")->makeChained("lbCtl", undef, sub {
		my $row = $_[1]->getRow();
		my ($cmd, $arg) = $row->toArray();
		if ($cmd eq "print") {
			printOrShut($app, $opts->{fragment}, $sock, $arg, "\n");
		} elsif ($cmd eq "subscribe") {
			$topics{$arg} = 1;
			printOrShut($app, $opts->{fragment}, $sock, "!subscribed,$arg\n");
		} elsif ($cmd eq "unsubscribe") {
			delete $topics{$arg};
			printOrShut($app, $opts->{fragment}, $sock, "!unsubscribed,$arg\n");
		} else {
			printOrShut($app, $opts->{fragment}, $sock, "!invalid command,$cmd,$arg\n");
		}
	});

	$owner->readyReady();

	$owner->mainLoop();

	$tsock->close(); # not strictly necessary
	print "XXX writer $tname exits\n";
}

if (0) {
	my ($port, $pid) = Triceps::X::ThreadedServer::startServer(
			app => "chat",
			main => \&listenerT,
			port => 0,
			fork => 1,
	);
	print "XXX port $port\n";
	waitpid($pid, 0);
}
if (0) {
	my ($port, $pid) = Triceps::X::ThreadedServer::startServer(
			app => "chat",
			main => \&listenerT,
			port => 12345,
			fork => 0,
	);
}
if (0) {
	my ($port, $thread) = Triceps::X::ThreadedServer::startServer(
			app => "chat",
			main => \&listenerT,
			port => 0,
			fork => -1,
	);
	print "XXX port $port\n";
	$thread->join();
}

##############################
# the client for automated testing

package Triceps::X::ThreadedClient;
use Carp;

# The client app has the following threads:
# * Global/main thread: controls the execution, sends the requests to the
#   other threads, eventually collects all the inputs form the sockets.
# * Per-client threads, as described below
# * Collector thread that collects the inputs from the client threads
#   and waits for patterns in it; eventually passes the collected
#   inputs to the main thread.

# Each client consists of the following threads:
# * writer: writes to the socket
# * reader: reads from the socket, passes data to the collector thread

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
			close => $rtMsg, # request to shut down the writing side of the socket (text is ignored)
		],
		import => "writer",
	);
	my $faRecv = $owner->makeNexus( # messages to received form the client readers
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
				&$catrecv($client);
				delete $pattern{$client};
				$unit->makeHashCall($lbRepMsg, "OP_INSERT", 
					cmd => "expect",
					client => $client,
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

	$faCtl->getLabel("ctl")->makeChained("lbCtl", undef, sub {
		my ($cmd, $client, $arg) = $_[1]->getRow()->toArray();
		if ($cmd eq "expect") {
			# expact a certain pattern from a client
			$pattern{$client} = qr/$arg/;
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

# The object is instantiated in the global/main thread.
#
# Options:
#
# owner => $TrieadOwner
# The thread owner wher this object is instantiated.
#
# port => $port
# Server port number, to which the clients will connect.
sub new # ($class, @opts)
{
	my $myname = "Triceps::X::ThreadedClient::new";
	my $class = shift;
	my $self = {};
	&Triceps::Opt::parse($class, $self, {
		owner => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::TrieadOwner") } ],
		port => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
}

package main;

if (0) {

my ($port, $pid) = Triceps::X::ThreadedServer::startServer(
		app => "chat",
		main => \&listenerT,
		port => 0,
		fork => 1,
);
print "XXX port $port\n";

Triceps::App::build "client", sub {
	my $appname = $Triceps::App::name;
	my $owner = $Triceps::App::global;

	my %clients;
};

waitpid($pid, 0);

}
