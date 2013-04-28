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
use Carp;
use IO::Socket;
use IO::Socket::INET;
ok(1); # If we made it this far, we're ok.

exit 0; # XXX disable the logic

#########################

# Listener for connections.
# Options:
#
# socket => $file
# The socket object.
#
sub ListenerT
{
	my $opts = {};
	&Triceps::Opt::parse("ListenerT", $opts, {@Triceps::Triead::opts,
		socketName => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_;
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $tname = $opts->{thread};
	my $clid = 0; # client id

	my ($tsock, $sock) = $owner->trackGetSocket($opts->{socketName}, "+<");

	$owner->readyReady();

	while(!$owner->isRqDead()) {
		my $client = $sock->accept();
		if (!defined $client) {
			my $err = $!;
			if ($owner->isRqDead()) {
				$tsock->close();
				last;
			} elsif($!{EAGAIN} || $!{EINTR}) {
				next;
			} else {
				confess "ListenerT $tname: accept failed: $!";
			}
		}
		$clid++;
		my $cliname = "conn$clid";
		printf("XXX fd  %d\n", fileno($client));
		$app->storeFile($cliname, $client);
		close($client);

		Triceps::Triead::start(
			app => $opts->{app},
			thread => $cliname,
			fragment => $cliname,
			main => \&ChatSockReadT,
			socketName => $cliname,
		);

		$owner->readyReady();
		# by now that fd has been extracted
		$app->closeFd($cliname);
	}
}

# The socket reading side of the client connection.
sub ChatSockReadT
{
	my $opts = {};
	&Triceps::Opt::parse("ListenerT", $opts, {@Triceps::Triead::opts,
		socketName => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_; # avoids a leak in threads module
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $unit = $owner->unit();
	my $tname = $opts->{thread};

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
		main => \&ChatSockWriteT,
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

# Sends the data to a socket, on error shuts down the fragment.
sub printOrShutdown # ($app, $fragment, $sock, @text)
{
	my $app = shift;
	my $fragment = shift;
	my $sock = shift;

	undef $!;
	print $sock @_;
	$sock->flush();

	if ($!) { # can't write, so shutdown
		$app->shutdownFragment($fragment);
	}
}

# The socket writing side of the client connection.
sub ChatSockWriteT
{
	my $opts = {};
	&Triceps::Opt::parse("ListenerT", $opts, {@Triceps::Triead::opts,
		socketName => [ undef, \&Triceps::Opt::ck_mandatory ],
		ctlFrom => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_;
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $tname = $opts->{thread};

	my ($tsock, $sock) = $owner->trackDupSocket($opts->{socketName}, ">");

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
		printOrShutdown($app, $opts->{fragment}, $sock, "XXX got topic '$topic'\n");
		if ($topic eq "*" || exists $topics{$topic}) {
			printOrShutdown($app, $opts->{fragment}, $sock, $topic, ",", $row->get("msg"), "\n");
		}
	});

	$faCtl->getLabel("ctl")->makeChained("lbCtl", undef, sub {
		my $row = $_[1]->getRow();
		my ($cmd, $arg) = $row->toArray();
		if ($cmd eq "print") {
			printOrShutdown($app, $opts->{fragment}, $sock, $arg, "\n");
		} elsif ($cmd eq "subscribe") {
			$topics{$arg} = 1;
			printOrShutdown($app, $opts->{fragment}, $sock, "!subscribed,$arg\n");
		} elsif ($cmd eq "unsubscribe") {
			delete $topics{$arg};
			printOrShutdown($app, $opts->{fragment}, $sock, "!unsubscribed,$arg\n");
		} else {
			printOrShutdown($app, $opts->{fragment}, $sock, "!invalid command,$cmd,$arg\n");
		}
	});

	$owner->readyReady();

	$owner->mainLoop();

	$tsock->close(); # not strictly necessary
	print "XXX writer $tname exits\n";
}

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

Triceps::App::build "chat", sub {
	Triceps::App::globalNexus(
		name => "chat",
		labels => [
			msg => $rtMsg,
		],
		rowTypes => [
			ctl => $rtCtl,
		],
	);

	my $srvsock = IO::Socket::INET->new(
		Proto => "tcp",
		LocalPort => 0,
		Listen => 10,
	) or confess "socket failed: $!";
	my $port = $srvsock->sockport() or confess "sockport failed: $!";
	$Triceps::App::app->storeFile("global.listen", $srvsock);
	close($srvsock);

	Triceps::Triead::start(
		app => $Triceps::App::name,
		thread => "listener",
		main => \&ListenerT,
		socketName => "global.listen",
	);
	close($srvsock); # reference counted, close in each thread

	print "XXX port $port\n";
};
