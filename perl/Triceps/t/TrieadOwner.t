#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for App handling.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl App.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;
use strict;
use threads;

use Test;
BEGIN { plan tests => 194 };
use Triceps;
use Carp;
ok(1); # If we made it this far, we're ok.

#########################
# stuff that will be used repeatedly

my @def1 = (
	a => "uint8",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
my $rt1 = Triceps::RowType->new( # used later
	@def1
);
ok(ref $rt1, "Triceps::RowType");

#########################

# basic construction (and along the way App::declareTriead and
# App::getTrieads)
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	$a1->declareTriead("t1");
	my @ts;
	@ts = $a1->getTrieads();
	ok($#ts, 1);
	ok($ts[0], "t1");
	ok(!defined $ts[1]); # declared but not defined, so returns an undef

	my $to1 = Triceps::TrieadOwner->new(undef, $a1, "t1", "");
	ok(ref $to1, "Triceps::TrieadOwner");
	Triceps::App::declareTriead("a1", "t1"); # repeat

	my $t1 = $to1->get();
	ok(ref $t1, "Triceps::Triead");
	ok($t1->getName(), "t1");

	my $unit = $to1->unit();
	ok(ref $unit, "Triceps::Unit");

	my $to2 = Triceps::TrieadOwner->new(undef, "a1", "t2", "");
	ok(ref $to2, "Triceps::TrieadOwner");

	my $t2 = $to2->get();
	ok(ref $t2, "Triceps::Triead");
	ok($t2->getName(), "t2");

	@ts = $a1->getTrieads();
	ok($#ts, 3);
	# the map in C++ orders the entries alphabetically
	ok($ts[0], "t1");
	ok(ref $ts[1], "Triceps::Triead");
	ok($t1->same($ts[1]));
	ok($ts[2], "t2");
	ok(ref $ts[3], "Triceps::Triead");
	ok($t2->same($ts[3]));

	# try the other App identification
	@ts = Triceps::App::getTrieads("a1");
	ok($#ts, 3);

	$a1->drop();
}

# construction with an actual thread
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	$a1->declareTriead("t1");
	my $thr1 = async {
		my $self = threads->self();
		my $tid = $self->tid();
		my $to1 = Triceps::TrieadOwner->new($tid, "a1", "t1", "");

		# go through all the markings
		$to1->markConstructed();
		$to1->markReady();
		$to1->readyReady();
		$to1->markDead();
	};

	$a1->harvester(); # this ensures that the thread had all properly completed
	ok(!$thr1->is_running());
}

# construction with Triead::start
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	Triceps::Triead::start(
		app => "a1",
		thread => "t1",
		main => sub {
			my $opts = {};
			&Triceps::Opt::parse("t1 main", $opts, {@Triceps::Triead::opts}, @_);
			ok(ref $opts->{owner}, "Triceps::TrieadOwner");
			ok(!$opts->{owner}->isDead());
		},
	);

	# the TrieadOwner destruction will mark it dead
	$a1->harvester(); # this ensures that the thread had all properly completed

	$Test::ntest += 2; # include the tests in the thread

	# even through a1 is dropped from the list, it's still accessible and has contents
	my @ts = $a1->getTrieads();
	ok($#ts, 1);
	ok($ts[1]->getName(), "t1");
	ok($ts[1]->isDead());
}

# catch of a die() as a thread abort
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	Triceps::Triead::start(
		app => "a1",
		thread => "t1",
		main => sub {
			die "test error"
		},
	);

	# the TrieadOwner destruction will mark it dead
	eval { $a1->harvester(); }; # this ensures that the thread had all properly completed
	ok($@, qr/App 'a1' has been aborted by thread 't1': test error/);
}

# construction with Triead::startHere
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	Triceps::Triead::startHere(
		app => "a1",
		thread => "t1",
		main => sub {
			my $opts = {};
			&Triceps::Opt::parse("t1 main", $opts, {@Triceps::Triead::opts}, @_);
			ok(ref $opts->{owner}, "Triceps::TrieadOwner");
			ok(!$opts->{owner}->isDead());
		},
	);

	eval { &Triceps::App::find("a1"); };
	ok($@, qr/^Triceps application 'a1' is not found/);

	# even through a1 is dropped from the list, it's still accessible and has contents
	my @ts = $a1->getTrieads();
	ok($#ts, 1);
	ok($ts[1]->getName(), "t1");
	ok($ts[1]->isDead());
}

# startHere with no harvest
# And along the way test the Triead state changes.
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	my $t; # will contain the Triead created
	Triceps::Triead::startHere(
		app => "a1",
		thread => "t1",
		fragment => "frag",
		main => sub {
			my $opts = {};
			&Triceps::Opt::parse("t1 main", $opts, {@Triceps::Triead::opts}, @_);
			my $ow = $opts->{owner};
			ok(ref $ow, "Triceps::TrieadOwner");
			ok($ow->getName(), "t1");
			ok($ow->fragment(), "frag");
			ok(!$ow->isConstructed());
			ok(!$ow->isReady());
			ok(!$ow->isDead());
			ok(!$ow->isInputOnly()); # false before the Triead is constructed

			$t = $ow->get();
			ok(ref $t, "Triceps::Triead");
			ok($t->getName(), "t1");
			ok($t->fragment(), "frag");
			ok(!$t->isConstructed());
			ok(!$t->isReady());
			ok(!$t->isDead());
			ok(!$t->isInputOnly()); # false before the Triead is constructed

			$ow->markConstructed();
			ok($ow->isConstructed());
			ok($t->isConstructed());

			$ow->markReady();
			ok($ow->isReady());
			ok($t->isReady());

			ok($ow->isInputOnly()); # no reader facets
			ok($t->isInputOnly());

			$ow->readyReady(); # since no other threads, will succeed

			$ow->markDead();
			ok($ow->isDead());
			ok($t->isDead());

			# test the abort
			$ow->abort("test msg");
			ok($ow->app()->isAborted());
		},
		harvest => 0,
	);
	ok(ref $t, "Triceps::Triead");

	# The app is still here, unharvested.
	ok($a1->same(&Triceps::App::find("a1")));
	my @ts = $a1->getTrieads();
	ok($#ts, 1);
	ok($t->same($ts[1]));
	ok($ts[1]->getName(), "t1");
	ok($ts[1]->isDead());

	eval { $a1->harvester(); };
	ok($@, qr/^App 'a1' has been aborted by thread 't1': test msg/);
}

sub badNexus # (trieadOwner, optName, optValue, ...)
{
	my $to = shift;
	my %opt = (
		name => "nx",
		labels => [
			one => $rt1,
		],
		import => "NO",
	);
	while ($#_ >= 1) {
		if (defined $_[1]) {
			$opt{$_[0]} = $_[1];
		} else {
			delete $opt{$_[0]};
		}
		shift; shift;
	}
	my $res = eval {
		$to->makeNexus(%opt);
	};
	ok(!defined $res);
}

# makeNexus
# this one also tests Facet
{
	my $a1 = Triceps::App::make("a1");
	ok(ref $a1, "Triceps::App");

	my $to1 = Triceps::TrieadOwner->new(undef, $a1, "t1", "");
	ok(ref $to1, "Triceps::TrieadOwner");
	my $t1 = $to1->get();
	ok(ref $t1, "Triceps::Triead");

	my $lb = $to1->unit()->makeDummyLabel($rt1, "lb");
	my $tt = Triceps::TableType->new($rt1)
		->addSubIndex("by_b", 
			Triceps::IndexType->newHashed(key => [ "b" ])
		)
	or confess "$!";

	my $fa;
	my $fret;
	my @exp;

	$fa = $to1->makeNexus(
		name => "nx1",
		labels => [
			one => $rt1,
			two => $lb,
		],
	    rowTypes => [
			one => $rt1,
		],
	    tableTypes => [
			one => $tt,
		],
		reverse => 0,
		queueLimit => 100,
		import => "writer",
	);
	ok(ref $fa, "Triceps::Facet");

	#########
	# Test of Facet methods
	ok($fa->same($fa));
	ok($fa->getShortName(), "nx1");
	ok($fa->getFullName(), "t1/nx1");
	ok($fa->isWriter());
	ok(!$fa->isReverse());
	ok($fa->queueLimit(), 100);
	ok($fa->beginIdx(), 2);
	ok($fa->endIdx(), 3);

	@exp = $fa->impRowTypesHash();
	ok($#exp, 1);
	ok($exp[0], "one");
	ok(ref $exp[1], "Triceps::RowType");
	ok($rt1->same($exp[1])); # since it's a reimport, the type will stay the same

	ok($rt1->same($fa->impRowType("one")));
	eval { $fa->impRowType("zzz"); };
	ok($@, qr/^Triceps::Facet::impRowType: unknown row type name 'zzz'/);

	@exp = $fa->impTableTypesHash();
	ok($#exp, 1);
	ok($exp[0], "one");
	ok(ref $exp[1], "Triceps::TableType");
	ok($tt->same($exp[1])); # since it's a reimport, the type will stay the same

	ok($tt->same($fa->impTableType("one")));
	eval { $fa->impTableType("zzz"); };
	ok($@, qr/^Triceps::Facet::impTableType: unknown table type name 'zzz'/);

	$fret = $fa->getFnReturn();
	ok(ref $fret, "Triceps::FnReturn");
	ok($fret->getName(), "nx1");

	eval { $fa->flushWriter(); };
	ok($@, qr/^Can not flush the facet 't1\/nx1' before waiting for App readiness/);

	#########
	@exp = $t1->exports(); # the C++ map imposes the order
	ok($#exp, 1);
	ok($exp[0], "nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");
	ok($fa->nexus()->same($exp[1]));

	@exp = $t1->imports();
	ok($#exp, 1);
	ok($exp[0], "t1/nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");
	ok($fa->nexus()->same($exp[1]));

	@exp = $t1->writerImports();
	ok($#exp, 1);
	ok($exp[0], "t1/nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");
	ok($fa->nexus()->same($exp[1]));

	@exp = $t1->readerImports();
	ok($#exp, -1);

	# TrieadOwner::exports produced the same result as its Triead::exports
	@exp = $to1->exports(); # the C++ map imposes the order
	ok($#exp, 1);
	ok($exp[0], "nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");

	@exp = $to1->imports();
	ok($#exp, 1);
	ok($exp[0], "t1/nx1");
	ok(ref $exp[1], "Triceps::Facet");
	ok($fa->same($exp[1]));

	#########
	# minimum of options
	$fa = $to1->makeNexus(
		name => "nx2",
		labels => [
			one => $rt1,
			two => $lb,
		],
		import => "reader",
	);
	ok(ref $fa, "Triceps::Facet");
	ok(!$fa->isWriter());

	#########
	@exp = $t1->exports(); # the C++ map imposes the order
	ok($#exp, 3);
	ok($exp[0], "nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");
	ok($exp[2], "nx2");
	ok(ref $exp[3], "Triceps::Nexus");
	ok($exp[3]->getName(), "nx2");
	ok($fa->nexus()->same($exp[3]));

	@exp = $t1->imports();
	ok($#exp, 3);
	ok($exp[0], "t1/nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");
	ok($exp[2], "t1/nx2");
	ok(ref $exp[3], "Triceps::Nexus");
	ok($exp[3]->getName(), "nx2");

	@exp = $t1->writerImports();
	ok($#exp, 1);
	ok($exp[0], "t1/nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");

	@exp = $t1->readerImports();
	ok($#exp, 1);
	ok($exp[0], "t1/nx2");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx2");
	ok($fa->nexus()->same($exp[1]));

	# TrieadOwner::exports produced the same result as its Triead::exports
	@exp = $to1->exports(); # the C++ map imposes the order
	ok($#exp, 3);
	ok($exp[0], "nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");
	ok($exp[2], "nx2");
	ok(ref $exp[3], "Triceps::Nexus");
	ok($exp[3]->getName(), "nx2");

	@exp = $to1->imports();
	ok($#exp, 3);
	ok($exp[0], "t1/nx1");
	ok(ref $exp[1], "Triceps::Facet");
	ok($exp[2], "t1/nx2");
	ok(ref $exp[3], "Triceps::Facet");
	ok($fa->same($exp[3]));

	#########
	# minimum of options
	$fa = $to1->makeNexus(
		name => "nx3",
		labels => [
			one => $rt1,
			two => $lb,
		],
		import => "none",
	);
	ok(!defined $fa);

	#########
	@exp = $t1->exports(); # the C++ map imposes the order
	ok($#exp, 5);
	ok($exp[0], "nx1");
	ok(ref $exp[1], "Triceps::Nexus");
	ok($exp[1]->getName(), "nx1");
	ok($exp[2], "nx2");
	ok(ref $exp[3], "Triceps::Nexus");
	ok($exp[3]->getName(), "nx2");
	ok($exp[4], "nx3");
	ok(ref $exp[5], "Triceps::Nexus");
	ok($exp[5]->getName(), "nx3");

	#########
	# short versions of the import values
	$to1->makeNexus(
		name => "nx4",
		labels => [
			one => $rt1,
			two => $lb,
		],
		import => "WRITE",
	);
	$to1->makeNexus(
		name => "nx5",
		labels => [
			one => $rt1,
			two => $lb,
		],
		import => "READ",
	);
	$to1->makeNexus(
		name => "nx6",
		labels => [
			one => $rt1,
			two => $lb,
		],
		import => "NO",
	);

	# the errors
	&badNexus($to1, name => "nx1");
	ok($@, qr/Triceps::TrieadOwner::makeNexus: invalid arguments:\n  Can not export the nexus with duplicate name 'nx1' in app 'a1' thread 't1'/);
	&badNexus($to1, name => undef);
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: must specify a non-empty name with option 'name'/);
	&badNexus($to1, labels => undef);
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: missing mandatory option 'labels'/);
	&badNexus($to1, import => undef);
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: the option 'import' must have the value one of 'writer', 'reader', 'no'; got ''/);
	&badNexus($to1, labels => {a => 9});
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: option 'labels' value must be a reference to array/);
	&badNexus($to1, labels => [a => 9]);
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: in option 'labels' element 1 with name 'a' value must be a blessed SV reference to Triceps::Label or Triceps::RowType/);
	&badNexus($to1, import => "xxx");
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: the option 'import' must have the value one of 'writer', 'reader', 'no'; got 'xxx'/);
	&badNexus($to1, rowTypes => {a => $rt1});
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: option 'rowTypes' value must be a reference to array/);
	&badNexus($to1, rowTypes => [a => $tt]);
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: in option 'rowTypes' element 1 with name 'a' value has an incorrect magic/);
	&badNexus($to1, tableTypes => {a => $tt});
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: option 'tableTypes' value must be a reference to array/);
	&badNexus($to1, tableTypes => [a => $rt1]);
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: in option 'tableTypes' element 1 with name 'a' value has an incorrect magic for Triceps::TableType/);

	$to1->markConstructed();
	&badNexus($to1);
	ok($@, qr/^Triceps::TrieadOwner::makeNexus: invalid arguments:\n  Can not export the nexus 'nx' in app 'a1' thread 't1' that is already marked as constructed/);

	$a1->drop();
}
