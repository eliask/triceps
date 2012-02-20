#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for PerlSortedIndexType.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 47 };
use Triceps;
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
# with no initializer, only comparator

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

{
	$tt1 = Triceps::TableType->new($rt1)
		->addSubIndex("primary", $it1)
	;
	ok(ref $tt1, "Triceps::TableType");

	$res = $tt1->initialize();
	ok($res, 1);
	#print STDERR "$!" . "\n";

	$t1 = $u1->makeTable($tt1, "EM_CALL", "t1");
	ok(ref $t1, "Triceps::Table");

	# insert rows in a backwards order
	$r11 = $rt1->makeRowHash(b => 1, c => 1);
	$r12 = $rt1->makeRowHash(b => 1, c => 2);
	$r21 = $rt1->makeRowHash(b => 2, c => 1);
	$r22 = $rt1->makeRowHash(b => 2, c => 2);

	ok($res = $t1->insert($r22));
	ok($res = $t1->insert($r21));
	ok($res = $t1->insert($r12));
	ok($res = $t1->insert($r11));

	# iterate, they should come in the sorted order
	$iter = $t1->begin();
	ok($r11->same($iter->getRow()));
	$iter = $iter->next();
	ok($r12->same($iter->getRow()));
	$iter = $iter->next();
	ok($r21->same($iter->getRow()));
	$iter = $iter->next();
	ok($r22->same($iter->getRow()));
	$iter = $iter->next();
	ok($iter->isNull());

	# do a successful find
	$iter = $t1->find($rt1->makeRowHash(b => 1, c => 2));
	ok($r12->same($iter->getRow()));

	# do an unsuccessful find
	$iter = $t1->find($rt1->makeRowHash(b => 1, c => 3));
	ok($iter->isNull());
};

#########################
# with no initializer, only comparator, nested index,
# also test the copying

{
	# add a sub-index to the copy
	$it2 = $it1->copy();
	$it2->addSubIndex("leaf", Triceps::IndexType->newFifo());

	$tt1 = Triceps::TableType->new($rt1)
		->addSubIndex("primary", $it2)
	;
	ok(ref $tt1, "Triceps::TableType");

	$res = $tt1->initialize();
	ok($res, 1);
	#print STDERR "$!" . "\n";

	# get back the copied object from the table type
	$it2 = $tt1->findSubIndex("primary");
	ok(ref $it2, "Triceps::IndexType");
	$it3 = $it2->findSubIndex("leaf");
	ok(ref $it3, "Triceps::IndexType");

	$t1 = $u1->makeTable($tt1, "EM_CALL", "t1");
	ok(ref $t1, "Triceps::Table");

	# insert rows in a backwards order, with multiple copies of some
	$r11 = $rt1->makeRowHash(b => 1, c => 1);
	$r12 = $rt1->makeRowHash(b => 1, c => 2);
	$r21 = $rt1->makeRowHash(b => 2, c => 1);
	$r22 = $rt1->makeRowHash(b => 2, c => 2);

	ok($res = $t1->insert($r22));

	ok($res = $t1->insert($r21));
	ok($res = $t1->insert($r21));
	ok($res = $t1->insert($r21));

	ok($res = $t1->insert($r12));
	ok($res = $t1->insert($r11));

	# iterate, they should come in the sorted order
	$iter = $t1->begin();
	ok($r11->same($iter->getRow()));
	$iter = $iter->next();
	ok($r12->same($iter->getRow()));

	$iter = $iter->next();
	ok($r21->same($iter->getRow()));
	$iter = $iter->next();
	ok($r21->same($iter->getRow()));
	$iter = $iter->next();
	ok($r21->same($iter->getRow()));

	$iter = $iter->next();
	ok($r22->same($iter->getRow()));
	$iter = $iter->next();
	ok($iter->isNull());

	# do a successful find of group
	$iter = $t1->findIdx($it2, $rt1->makeRowHash(b => 2, c => 1));
	ok($r21->same($iter->getRow()));
	$iter2 = $iter->nextGroupIdx($it3);
	ok($r22->same($iter2->getRow()));

	# do an unsuccessful find of group
	$iter = $t1->findIdx($it2, $rt1->makeRowHash(b => 1, c => 3));
	ok($iter->isNull());
};

#########################
# test the catching of errors in comparator
# with no initializer, only comparator

{
	my $comp; # pointer to the actual comparator
	$it3 = Triceps::IndexType->newPerlSorted("bad", undef, sub {
		return unless defined $comp; # with no value
		return &$comp(@_);
	});
	ok(ref $it1, "Triceps::IndexType");

	$tt1 = Triceps::TableType->new($rt1)
		->addSubIndex("primary", $it3)
	;
	ok(ref $tt1, "Triceps::TableType");

	$res = $tt1->initialize();
	ok($res, 1);
	#print STDERR "$!" . "\n";

	$t1 = $u1->makeTable($tt1, "EM_CALL", "t1");
	ok(ref $t1, "Triceps::Table");

	$r11 = $rt1->makeRowHash(b => 1, c => 1);
	$r12 = $rt1->makeRowHash(b => 1, c => 2);

	# inserting the 1st row doesn't trigger a comparator
	ok($res = $t1->insert($r12));
	# insert 2nd row, to trigger the error messages

	# a death in comparator
	$comp = sub {
		die "test a death in PerlSortedIndex comparator\n";
	};
	print STDERR "\nExpect message(s) like: Error in PerlSortedIndex(bad) comparator: test a death in PerlSortedIndex comparator\n";
	ok($res = $t1->insert($r11));

	# a string return value in comparator
	$comp = sub {
		return "zzz";
	};
	print STDERR "\nExpect message(s) like: Error in PerlSortedIndex(bad) comparator: comparator returned a non-integer value\n";
	ok($res = $t1->insert($r11));

	# no return value in comparator - same error message as before, plus a cmplaint from Perl test, so comment it out
	#$comp = undef;
	#print STDERR "\nExpect message(s) like: Error in PerlSortedIndex(bad) comparator: comparator returned a non-integer value\n";
	#ok($res = $t1->insert($r11));

};
