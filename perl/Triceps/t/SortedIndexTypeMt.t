#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for PerlSortedIndexType's interaction with threads.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 7 };
use Triceps;
use Carp;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################
# common definitions

$u1 = Triceps::Unit->new("u1");
ok(ref $u1, "Triceps::Unit");

@def1 = (
	a => "uint8",
	b => "int32",
	c => "int64",
	d => "float64",
	e => "string",
);
$rt1 = Triceps::RowType->new( # used later
	@def1
);
ok(ref $rt1, "Triceps::RowType");

#########################
# create an index with no initializer, only comparator

$it1 = Triceps::IndexType->newPerlSorted("basic", undef, sub {
	#print STDERR "comparing\n";
	#print STDERR "      ", $_[0]->printP(), "\n";
	#print STDERR "      ", $_[1]->printP(), "\n";
	my $res = ($_[0]->get("b") <=> $_[1]->get("b")
		|| $_[0]->get("c") <=> $_[1]->get("c"));
	#print STDERR "      result $res\n";
	return $res;
});
ok(ref $it1, "Triceps::IndexType");
$res = $it1->print();
ok($res, "index PerlSortedIndex(basic)");


#########################

{
	my $res;

	Triceps::Triead::startHere(
		app => "a1",
		thread => "main",
		main => sub {
			my $opts = {};
			&Triceps::Opt::parse("main main", $opts, {@Triceps::Triead::opts}, @_);
			my $owner = $opts->{owner};
			my $app = $owner->app();
			my $unit = $owner->unit();

			my $tt1 = Triceps::TableType->new($rt1)
				#->addSubIndex("primary", $it1)
				->addSubIndex("primary", Triceps::IndexType->newHashed(key => [ "b", "c" ]))
			;
			ok(ref $tt1, "Triceps::TableType");
			$tt1->initialize() or confess "$!";

			my $faOut = $owner->makeNexus(
				name => "source",
				labels => [
					data => $rt1, # data to forward to the table
					dump => $rt1, # the row type doesn't matter
				],
				tableTypes => [
					tt1 => $tt1,
				],
				import => "writer",
			);

			my $faIn = $owner->makeNexus(
				name => "sink",
				labels => [
					out => $rt1, # normal table output
					dump => $rt1, # table's dump
				],
				reverse => 1,
				import => "reader",
			);

			$owner->markConstructed();

			Triceps::Triead::start(
				app => "a1",
				thread => "th1",
				main => sub {
					my $opts = {};
					&Triceps::Opt::parse("th1 main", $opts, {@Triceps::Triead::opts}, @_);
					my $owner = $opts->{owner};
					my $unit = $owner->unit();

					my $faSource = $owner->importNexus(
						from => "main/source",
						import => "reader",
					);
					my $faSink = $owner->importNexus(
						from => "main/sink",
						import => "writer",
					);

					my $tt1 = $faSource->impTableType("tt1");
					$tt1->initialize() or confess "$!";
					my $t1 = $unit->makeTable($tt1, "EM_CALL", "t1") or confess "$!";

					$faSource->getLabel("data")->chain($t1->getInputLabel());
					$t1->getOutputLabel()->chain($faSink->getLabel("out"));
					$t1->getDumpLabel()->chain($faSink->getLabel("dump"));

					$faSource->getLabel("dump")->makeChained("dump", undef, sub {
						$t1->dumpAll();
						#$t1->dump(); # this triggers an interesting error
					});

					$owner->readyReady();
					$owner->mainLoop();
					$owner->markDead();
				},
			);

			$faIn->getLabel("out")->makeChained("indata", undef, sub {
				$res .= $_[1]->printP() . "\n";
			});
			$faIn->getLabel("dump")->makeChained("indump", undef, sub {
				$res .= $_[1]->printP() . "\n";
			});

			my $odata = $faOut->getLabel("data");
			my $odump = $faOut->getLabel("dump");

			$owner->readyReady();

			# insert the rows in reverse order
			$unit->makeHashCall($odata, "OP_INSERT", b => 2, c => 2);
			$unit->makeHashCall($odata, "OP_INSERT", b => 2, c => 1);
			$unit->makeHashCall($odata, "OP_INSERT", b => 1, c => 2);
			$unit->makeHashCall($odata, "OP_INSERT", b => 1, c => 1);

			$unit->makeHashCall($odump, "OP_INSERT");
			$owner->flushWriters();

			Triceps::AutoDrain::makeExclusive($owner);
			while ($owner->nextXtrayNoWait()) { }
			$app->shutdown();
		},
	);
	#print $res;
	# XXX test for the real expected result
	ok(1); # if it got here, a success
}
