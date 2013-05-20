#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The example of queries in TQL (Triceps/Trivial Query Language)
# with multithreading.

#########################

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 3 };
use Triceps;
use Triceps::X::TestFeed qw(:all);
use Triceps::X::Tql;
use Triceps::X::ThreadedServer;
use Triceps::X::ThreadedClient;
use Carp;
ok(2); # If we made it this far, we're ok.

use strict;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################
# The simple App example.

package App1;
use Test;
use Carp;

sub appCoreT # (@opts)
{
	my $opts = {};
	&Triceps::Opt::parse("appCoreT", $opts, {@Triceps::Triead::opts,
		socketName => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	undef @_; # avoids a leak in threads module
	my $owner = $opts->{owner};
	my $app = $owner->app();
	my $unit = $owner->unit();

	# build the core logic

	my $rtTrade = Triceps::RowType->new(
		id => "int32", # trade unique id
		symbol => "string", # symbol traded
		price => "float64",
		size => "float64", # number of shares traded
	) or confess "$!";

	my $ttWindow = Triceps::TableType->new($rtTrade)
		->addSubIndex("bySymbol", 
			Triceps::SimpleOrderedIndex->new(symbol => "ASC")
				->addSubIndex("last2",
					Triceps::IndexType->newFifo(limit => 2)
				)
		)
		or confess "$!";
	$ttWindow->initialize() or confess "$!";

	# Represents the static information about a company.
	my $rtSymbol = Triceps::RowType->new(
		symbol => "string", # symbol name
		name => "string", # the official company name
		eps => "float64", # last quarter earnings per share
	) or confess "$!";

	my $ttSymbol = Triceps::TableType->new($rtSymbol)
		->addSubIndex("bySymbol", 
			Triceps::SimpleOrderedIndex->new(symbol => "ASC")
		)
		or confess "$!";
	$ttSymbol->initialize() or confess "$!";

	my $tWindow = $unit->makeTable($ttWindow, "EM_CALL", "tWindow")
		or confess "$!";
	my $tSymbol = $unit->makeTable($ttSymbol, "EM_CALL", "tSymbol")
		or confess "$!";

	# $tSymbol->getOutputLabel()->makeChained("dbgSymbol", undef, sub {
		# print "XXX ", $_[1]->printP(), "\n";
	# });

	# export the endpoints for TQL (it starts the listener)
	my $tql = Triceps::X::Tql->new(
		name => "tql",
		trieadOwner => $owner,
		socketName => $opts->{socketName},
		tables => [
			$tWindow,
			$tSymbol,
		],
		tableNames => [
			"window",
			"symbol",
		],
	);

	$owner->readyReady();

	$owner->mainLoop();
}

{
	my ($port, $thread) = Triceps::X::ThreadedServer::startServer(
			app => "appTql",
			main => \&appCoreT,
			port => 0,
			fork => -1, # create a thread, not a process
	);

	eval {
		Triceps::App::build "client", sub {
			my $appname = $Triceps::App::name;
			my $owner = $Triceps::App::global;

			# give the port in startClient
			my $client = Triceps::X::ThreadedClient->new(
				owner => $owner,
				totalTimeout => 10.,
				debug => 2,
			);

			$owner->readyReady();

			$client->startClient(c1 => $port);
			$client->expect(c1 => 'ready');

			$client->send(c1 => "subscribe,s1,symbol\n");
			$client->expect(c1 => 'subscribe,s1');

			$client->send(c1 => "d,symbol,OP_INSERT,ABC,ABC Corp,1.0\n");
			$client->expect(c1 => 'd,symbol,OP_INSERT,ABC,ABC Corp,1$');

			$client->send(c1 => "dump,d2,symbol\n");
			$client->expect(c1 => "^dump,d2,symbol");

			# this is dump with a duplicate subscription, so the
			# subscription part is really redundant
			$client->send(c1 => "dumpsub,ds3,symbol\n");
			$client->expect(c1 => "^dumpsub,ds3,symbol");

			$client->send(c1 => "d,symbol,OP_INSERT,DEF,Defense Corp,2.0\n");
			$client->expect(c1 => 'd,symbol,OP_INSERT,DEF,Defense Corp,2$');

			# this one is not echoed, becuase not subscribed yet
			$client->send(c1 => "d,window,OP_INSERT,1,ABC,101,10\n");

			# this is dump with a new subscription
			$client->send(c1 => "dumpsub,ds4,window\n");
			$client->expect(c1 => "^dumpsub,ds4,window");

			$client->send(c1 => "d,window,OP_INSERT,2,ABC,102,12\n");
			$client->expect(c1 => 'd,window,OP_INSERT,2,ABC,102,12$');

			$client->send(c1 => "shutdown\n");
			$client->expect(c1 => '__EOF__');

			print $client->getTrace();
			ok($client->getTrace(), 
'> connect c1
c1|ready
> c1|subscribe,s1,symbol
c1|subscribe,s1,symbol
> c1|d,symbol,OP_INSERT,ABC,ABC Corp,1.0
c1|d,symbol,OP_INSERT,ABC,ABC Corp,1
> c1|dump,d2,symbol
c1|startdump,d2,symbol
c1|d,symbol,OP_INSERT,ABC,ABC Corp,1
c1|dump,d2,symbol
> c1|dumpsub,ds3,symbol
c1|startdump,ds3,symbol
c1|d,symbol,OP_INSERT,ABC,ABC Corp,1
c1|dumpsub,ds3,symbol
> c1|d,symbol,OP_INSERT,DEF,Defense Corp,2.0
c1|d,symbol,OP_INSERT,DEF,Defense Corp,2
> c1|d,window,OP_INSERT,1,ABC,101,10
> c1|dumpsub,ds4,window
c1|startdump,ds4,window
c1|d,window,OP_INSERT,1,ABC,101,10
c1|dumpsub,ds4,window
> c1|d,window,OP_INSERT,2,ABC,102,12
c1|d,window,OP_INSERT,2,ABC,102,12
> c1|shutdown
c1|shutdown,,,,
c1|__EOF__
');
		};
	};

	# let the errors from the server to be printed first
	$thread->join();
	die $@ if $@;
}

# check that everything completed and not died
ok(1);
