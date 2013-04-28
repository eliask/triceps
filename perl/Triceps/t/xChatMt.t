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
BEGIN { plan tests => 3 };
use strict;
use Triceps;
use Triceps::X::TestFeed qw(:all);
use Triceps::X::ThreadedServer qw(printOrShut);
use Triceps::X::ThreadedClient;
use Carp;
ok(1); # If we made it this far, we're ok.

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
	# print "DBG reader $tname exits\n";
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
	# print "DBG  writer $tname exits\n";
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

######################

# The real test of the server.
{
	my ($port, $pid) = Triceps::X::ThreadedServer::startServer(
			app => "chat",
			main => \&listenerT,
			port => 0,
			fork => 1,
	);

	Triceps::App::build "client", sub {
		my $appname = $Triceps::App::name;
		my $owner = $Triceps::App::global;

		my $client = Triceps::X::ThreadedClient->new(
			owner => $owner,
			port => $port,
			debug => 0,
		);

		$owner->readyReady();

		$client->startClient("c1");
		$client->expect("c1", '!ready');

		$client->startClient("c2");
		$client->expect("c2", '!ready');

		$client->send("c1", "publish,*,zzzzzz\n");
		$client->expect("c1", '\*,zzzzzz');
		$client->expect("c2", '\*,zzzzzz');

		$client->send("c2", "garbage,trash\n");
		$client->expect("c2", '!invalid command,garbage,trash');

		$client->send("c2", "subscribe,A\n");
		$client->expect("c2", '!subscribed,A');

		$client->send("c1", "publish,A,xxx\n");
		$client->expect("c2", 'A,xxx');

		$client->send("c1", "subscribe,A\n");
		$client->expect("c1", '!subscribed,A');

		$client->send("c1", "publish,A,www\n");
		$client->expect("c1", 'A,www');
		$client->expect("c2", 'A,www');

		$client->send("c2", "unsubscribe,A\n");
		$client->expect("c2", '!unsubscribed,A');

		$client->send("c1", "publish,A,vvv\n");
		$client->expect("c1", 'A,vvv');

		$client->startClient("c3");
		$client->expect("c3", '!ready');
		$client->send("c3", "exit\n");
		$client->expect("c3", '__EOF__');

		$client->startClient("c4");
		$client->expect("c4", '!ready');
		$client->sendClose("c4", "WR");
		$client->expect("c4", '__EOF__');

		$client->send("c1", "shutdown\n");
		$client->expect("c1", '__EOF__');
		$client->expect("c2", '__EOF__');

		ok($client->protocol(),
'> connect c1
c1|!ready,cliconn1
> connect c2
c2|!ready,cliconn2
> c1|publish,*,zzzzzz
c1|*,zzzzzz
c2|*,zzzzzz
> c2|garbage,trash
c2|!invalid command,garbage,trash
> c2|subscribe,A
c2|!subscribed,A
> c1|publish,A,xxx
c2|A,xxx
> c1|subscribe,A
c1|!subscribed,A
> c1|publish,A,www
c1|A,www
c2|A,www
> c2|unsubscribe,A
c2|!unsubscribed,A
> c1|publish,A,vvv
c1|A,vvv
> connect c3
c3|!ready,cliconn3
> c3|exit
c3|!exiting
c3|__EOF__
> connect c4
c4|!ready,cliconn4
> close WR c4
c4|!exiting
c4|__EOF__
> c1|shutdown
c1|*,server shutting down
c1|__EOF__
c2|*,server shutting down
c2|__EOF__
');
	};

	waitpid($pid, 0);
}

# test that the ThreadedClient expect reads to the first match
{
	my ($port, $pid) = Triceps::X::ThreadedServer::startServer(
			app => "chat",
			main => \&listenerT,
			port => 0,
			fork => 1,
	);

	Triceps::App::build "client", sub {
		my $appname = $Triceps::App::name;
		my $owner = $Triceps::App::global;

		my $client = Triceps::X::ThreadedClient->new(
			owner => $owner,
			port => $port,
			debug => 0,
		);

		$owner->readyReady();

		$client->startClient("c1");
		$client->expect("c1", '!ready');

		$client->send("c1", "publish,*,zzzzzz\n");
		$client->send("c1", "publish,*,zzzzzz\n");

		$client->expect("c1", '\*,zzzzzz');
		$client->expect("c1", '\*,zzzzzz');

		$client->send("c1", "shutdown\n");
		$client->expect("c1", '__EOF__');

		ok($client->protocol(),
'> connect c1
c1|!ready,cliconn1
> c1|publish,*,zzzzzz
> c1|publish,*,zzzzzz
c1|*,zzzzzz
c1|*,zzzzzz
> c1|shutdown
c1|*,server shutting down
c1|__EOF__
');
	};

	waitpid($pid, 0);
}
