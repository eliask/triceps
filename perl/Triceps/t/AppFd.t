#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for App file descriptor handling.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl App.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;
use strict;
use threads;

use Test;
BEGIN { plan tests => 16 };
use Triceps;
use Carp;
use IO::Socket;
use IO::Socket::INET;
ok(1); # If we made it this far, we're ok.

#########################
# A lot of this is just the manual touch-tests.

sub ls # ($msg)
{
	# uncomment, to eyeball what is going on
	#print $_[0], "\n";
	#system("ls -l /proc/$$/fd");
}

Triceps::Triead::startHere(
	app => "a1",
	thread => "t1",
	main => sub {
		my $opts = {};
		&Triceps::Opt::parse("t1 main", $opts, {@Triceps::Triead::opts}, @_);
		my $owner = $opts->{owner};
		my $app = $owner->app();
		my $fd;

		# used for synchronization through draining
		my $faSync = $owner->makeNexus(
			name => "sync",
			import => "writer",
		);

		#############################
		# single-threaded, direct reuse

		open(A, "</dev/null") or confess "/dev/null error: $!";
		&ls("========= open");
		$app->storeFd("A", fileno(A));
		&ls("stored");
		close(A);
		&ls("closed orig");

		$fd = $app->loadFd("A");
		open(A, "<&$fd");
		&ls("reopened");
		open(B, "<&$fd");
		&ls("reopened 2");

		close(A);
		close(B);
		&ls("closed copies");

		open(A, "<&=$fd");
		&ls("reopened = 1");
		open(B, "<&=$fd");
		&ls("reopened = 2");

		close(A);
		&ls("closed = 1");
		close(B);
		&ls("closed = 2");

		$app->forgetFd("A");
		
		#############################
		# load with a dup

		open(A, "</dev/null") or confess "/dev/null error: $!";
		&ls("========= open for dup");
		$app->storeFd("A", fileno(A));
		&ls("stored");
		close(A);
		&ls("closed orig");

		$fd = Triceps::App::loadDupFd("a1", "A");
		&ls("dupped");
		open(A, "<&$fd");
		&ls("reopened");
		open(B, "<&$fd");
		&ls("reopened 2");

		close(A);
		close(B);
		&ls("closed copies");

		open(A, "<&=$fd");
		&ls("reopened = 1");
		open(B, "<&=$fd");
		&ls("reopened = 2");

		close(A);
		&ls("closed = 1");
		close(B);
		&ls("closed = 2");

		Triceps::App::closeFd("a1", "A");
		&ls("closed stored");

		#############################
		# multithreaded,

		open(A, "</dev/null") or confess "/dev/null error: $!";
		&ls("========= open MT");
		Triceps::App::storeFd("a1", "A", fileno(A));
		&ls("stored");
		close(A);
		&ls("closed orig");

		$fd = Triceps::App::loadFd("a1", "A");
		&ls("t1 loaded");
		open(A, "<&$fd");
		&ls("t1 reopened");

		Triceps::Triead::start(
			app => "a1",
			thread => "t2",
			main => sub {
				my $opts = {};
				&Triceps::Opt::parse("t2 main", $opts, {@Triceps::Triead::opts}, @_);
				my $owner = $opts->{owner};
				my $app = $owner->app();
				my $fd;

				my $faSync = $owner->importNexus(
					from => "t1/sync",
					import => "reader",
				);

				$fd = Triceps::App::loadFd("a1", "A");
				&ls("t2 loaded");
				open(A, "<&$fd");
				&ls("t2 reopened");

				$owner->readyReady();

				close(A);
				&ls("t2 closed");
			},
		);
		$owner->readyReady();

		Triceps::AutoDrain::makeShared($owner);

		close(A);
		&ls("t1 closed");

		$app->closeFd("A");
		&ls("closed stored");

if (0) {
		#############################
		# multithreaded, load with =
		# THIS DOES NOT WORK, NO COORDINATION BETWEEN PERL FILES IN DIFFERENT THREADS

		open(A, "</dev/null") or confess "/dev/null error: $!";
		&ls("========= open MT for <&=");
		Triceps::App::storeFd("a1", "A", fileno(A));
		&ls("stored");
		close(A);
		&ls("closed orig");

		$fd = Triceps::App::loadFd("a1", "A");
		&ls("t1 loaded");
		open(A, "<&=$fd");
		&ls("t1 reopened");

		Triceps::Triead::start(
			app => "a1",
			thread => "t3",
			main => sub {
				my $opts = {};
				&Triceps::Opt::parse("t3 main", $opts, {@Triceps::Triead::opts}, @_);
				my $owner = $opts->{owner};
				my $app = $owner->app();
				my $fd;

				my $faSync = $owner->importNexus(
					from => "t1/sync",
					import => "reader",
				);

				$fd = Triceps::App::loadFd("a1", "A");
				&ls("t2 loaded");
				open(A, "<&=$fd");
				&ls("t2 reopened");

				$owner->readyReady();

				close(A);
				&ls("t2 closed");
			},
		);
		$owner->readyReady();

		Triceps::AutoDrain::makeShared($owner);

		close(A);
		&ls("t1 closed");

		Triceps::App::forgetFd("a1", "A");
		&ls("forgot stored");
}

		#############################
		# multithreaded, load with =, must dup for each thread

		open(A, "</dev/null") or confess "/dev/null error: $!";
		&ls("========= open MT for dup <&=");
		Triceps::App::storeFd("a1", "A", fileno(A));
		&ls("stored");
		close(A);
		&ls("closed orig");

		$fd = Triceps::App::loadDupFd("a1", "A");
		&ls("t1 loaded");
		open(A, "<&=$fd");
		&ls("t1 reopened");

		Triceps::Triead::start(
			app => "a1",
			thread => "t4",
			main => sub {
				my $opts = {};
				&Triceps::Opt::parse("t4 main", $opts, {@Triceps::Triead::opts}, @_);
				my $owner = $opts->{owner};
				my $app = $owner->app();
				my $fd;

				my $faSync = $owner->importNexus(
					from => "t1/sync",
					import => "reader",
				);

				$fd = Triceps::App::loadDupFd("a1", "A");
				&ls("t2 loaded");
				open(A, "<&=$fd");
				&ls("t2 reopened");

				$owner->readyReady();

				close(A);
				&ls("t2 closed");
			},
		);
		$owner->readyReady();

		Triceps::AutoDrain::makeShared($owner);

		undef $!;
		close(A);
		ok($!, "");
		&ls("t1 closed");

		$app->closeFd("A");
		&ls("closed stored");
	},
);
ok(1);

my $n1; # the first descriptor that gets dupped to

# the small tests, and errors
Triceps::Triead::startHere(
	app => "a1",
	thread => "t1",
	main => sub {
		my $opts = {};
		&Triceps::Opt::parse("t1 main", $opts, {@Triceps::Triead::opts}, @_);
		my $owner = $opts->{owner};
		my $app = $owner->app();

		eval { $app->storeFd("x", -1); };
		ok($@, qr/^Triceps::App::storeFd: dup failed: Bad file descriptor/);

		$app->storeFd("x", 0);
		$n1 = $app->loadFd("x");
		my $n2 = $n1+1;
		eval { $app->storeFd("x", 1); };
		ok($@, qr/^store of duplicate descriptor 'x', new fd=$n2, existing fd=$n1/);

		# check that the failed descriptor got closed
		$app->storeFd("y", 0);
		ok($app->loadFd("y"), $n2);

		my $dup = $app->loadDupFd("x");
		ok($dup, $n2+1);
		open(F, "<&=$dup") or die "$!";
		close(F) or die "$!";

		eval { $app->loadFd("z"); };
		ok($@, qr/^Triceps::App::loadFd: unknown file descriptor 'z'/);
		eval { $app->loadDupFd("z"); };
		ok($@, qr/^Triceps::App::loadDupFd: unknown file descriptor 'z'/);

		eval { $app->forgetFd("z"); };
		ok($@, qr/^Triceps::App::forgetFd: unknown file descriptor 'z'/);
		eval { $app->closeFd("z"); };
		ok($@, qr/^Triceps::App::closeFd: unknown file descriptor 'z'/);

		# the successfull close
		$app->closeFd('y');

		# the successful forget ($n1 still contains 'x')
		$app->forgetFd('x');
		open(F, "<&=$n1") or die "$!";
		close(F) or die "$!";

		# now store one more fd, to check that the App destruction closes it
		$app->storeFd("z", 0);
		ok($app->loadFd("z"), $n1);
	},
);

Triceps::Triead::startHere(
	app => "a1",
	thread => "t1",
	main => sub {
		my $opts = {};
		&Triceps::Opt::parse("t1 main", $opts, {@Triceps::Triead::opts}, @_);
		my $owner = $opts->{owner};
		my $app = $owner->app();

		# store the file handle;
		# along the way check that the previous App closed its fds
		$app->storeFile("z", *STDIN);
		ok($app->loadFd("z"), $n1);

		# restore as file handles
		my $f1 = $app->loadDupFile("z", "<", "IO::Handle") or die "$!";
		ok(ref $f1, "IO::Handle");
		$f1->close() or die "$!";

		my $f2 = $app->loadDupIOHandle("z", "<") or die "$!";
		ok(ref $f2, "IO::Handle");
		$f2->close() or die "$!";

		my $f3 = $app->loadDupIOSocketINET("z", "<") or die "$!";
		ok(ref $f3, "IO::Socket::INET");
		$f3->close() or die "$!";
	},
);
