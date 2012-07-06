#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The test for TableType.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 75 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

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

$it1 = Triceps::IndexType->newHashed(key => [ "b", "c" ])
	->addSubIndex("fifo", Triceps::IndexType->newFifo()
	);
ok(ref $it1, "Triceps::IndexType");

###################### new #################################

$tt1 = Triceps::TableType->new($rt1);
ok(ref $tt1, "Triceps::TableType");

$ret = $tt1->rowType();
ok(ref $ret, "Triceps::RowType");

$ret = $tt1->getRowType();
ok(ref $ret, "Triceps::RowType");

###################### addSubIndex #################################

@res = $tt1->getSubIndexes();
ok($#res, -1);

# tt2 actually refers to the same C++ object as tt1
$tt2 = $tt1->addSubIndex("primary", $it1);
ok(ref $tt2, "Triceps::TableType");
ok($tt2->same($tt1));

# a copy of the index is added, the original is left unchanged
$res = $it1->getTabtype();
ok(!defined $res);
ok($! . "", "Triceps::IndexType::getTabtype: this index type does not belong to an initialized table type");

$tt3 = Triceps::TableType->new($rt1)
	->addSubIndex("primary", $it1);
ok(ref $tt3, "Triceps::TableType");

###################### equals #################################

$res = $tt1->equals($tt2);
ok($res);
$res = $tt1->match($tt2);
ok($res);

$res = $tt1->match($tt3);
ok($res);
$res = $tt1->equals($tt3);
ok($res);

$tt1->addSubIndex("second", Triceps::IndexType->newFifo());
# they still point to the same object!
$res = $tt1->equals($tt2);
ok($res);

$res = $tt1->match($tt3);
ok(!$res);

$res = $tt1->same($tt2);
ok($res);
$res = $tt1->same($tt3);
ok(!$res);

# with varying row type

$rt5 = Triceps::RowType->new( # an equal row type
	@def1
);
ok(ref $rt5, "Triceps::RowType");
ok($rt1->equals($rt5));
@def6 = ( # different field names, a matching row type
	A => "uint8",
	b => "int32",
	c => "int64",
	D => "float64",
	E => "string",
);
$rt6 = Triceps::RowType->new(
	@def6
);
ok(ref $rt6, "Triceps::RowType");
ok($rt1->match($rt6));

$tt5 = Triceps::TableType->new($rt5)->addSubIndex("primary", $it1);
ok(ref $tt5, "Triceps::TableType");
$tt6 = Triceps::TableType->new($rt6)->addSubIndex("different", $it1);
ok(ref $tt6, "Triceps::TableType");

$res = $tt3->equals($tt5);
ok($res);
$res = $tt3->match($tt5);
ok($res);

$res = $tt3->equals($tt6);
ok(!$res);
$res = $tt3->match($tt6);
ok($res);

###################### getSubIndexes #################################

@res = $tt1->getSubIndexes();
ok($#res, 3);
ok($res[0], "primary");
ok(ref $res[1], "Triceps::IndexType");
$res = $it1->equals($res[1]);
ok($res, 1);
ok($res[2], "second");
ok(ref $res[3], "Triceps::IndexType");
$res = $res[3]->getIndexId();
ok($res, &Triceps::IT_FIFO);

###################### print #################################

$res = $tt1->print();
ok($res, "table (\n  row {\n    uint8 a,\n    int32 b,\n    int64 c,\n    float64 d,\n    string e,\n  }\n) {\n  index HashedIndex(b, c, ) {\n    index FifoIndex() fifo,\n  } primary,\n  index FifoIndex() second,\n}");
$res = $tt1->print(undef);
ok($res, "table ( row { uint8 a, int32 b, int64 c, float64 d, string e, } ) { index HashedIndex(b, c, ) { index FifoIndex() fifo, } primary, index FifoIndex() second, }");

###################### find #################################

$it2 = $tt1->getFirstLeaf();
$res = $it2->print();
ok($res, "index FifoIndex()");

# until the table type is initialized, indexes still don't know about it...
$res = $it2->getTabtype();
ok(!defined $res);
ok($! . "", "Triceps::IndexType::getTabtype: this index type does not belong to an initialized table type");

$it2 = $tt1->findSubIndex("primary");
$res = $it2->print();
ok($res, "index HashedIndex(b, c, ) {\n  index FifoIndex() fifo,\n}");
$res = $it2->print(undef);
ok($res, "index HashedIndex(b, c, ) { index FifoIndex() fifo, }");

$it2 = $tt1->findSubIndex("xxx");
ok(!defined($it2));

$it2 = $tt1->findSubIndexById("IT_FIFO");
ok(ref $it2, "Triceps::IndexType");

$it2 = $tt1->findSubIndexById(&Triceps::IT_FIFO);
ok(ref $it2, "Triceps::IndexType");

$it2 = $tt1->findSubIndexById(&Triceps::IT_ROOT);
ok(!defined $it2);
ok($! . "", "Triceps::TableType::findSubIndexById: no nested index with type id 'IT_ROOT' (0)");

$it2 = $tt1->findSubIndexById(999);
ok(!defined $it2);
ok($! . "", "Triceps::TableType::findSubIndexById: no nested index with type id '???' (999)");

$it2 = $tt1->findSubIndexById("xxx");
ok(!defined $it2);
ok($! . "", "Triceps::TableType::findSubIndexById: unknown IndexId string 'xxx', if integer was meant, it has to be cast");

$tt4 = Triceps::TableType->new($rt1);
$it2 = $tt4->getFirstLeaf();
ok(!defined($it2));

$it2 = $tt1->findIndexPath("primary", "fifo");
$res = $it2->print();
ok($res, "index FifoIndex()");

{
	# duplicating fields in the nested indexes are not a good idea,
	# but just for the test...
	my $ttDeep = Triceps::TableType->new($rt1)
		->addSubIndex("xab", # for iteration in order grouped by source
			Triceps::IndexType->newHashed(key => [ "a", "b" ])
			->addSubIndex("xbc", 
				Triceps::IndexType->newHashed(key => [ "c" ])
			)
		)
	;
	ok(ref $ttDeep, "Triceps::TableType");
	my ($it, @keys) = $ttDeep->findIndexKeyPath("xab", "xbc");
	ok(ref $it, "Triceps::IndexType");
	ok(join(",", @keys), "a,b,c");
}

$it2 = eval {
	$tt1->findIndexPath("primary", "zzz");
};
#print STDERR "$@\n";
ok($@ =~ /Triceps::TableType::findIndexPath: unable to find the index type at path 'primary.zzz', table type is:
table \(
  row \{
    uint8 a,
    int32 b,
    int64 c,
    float64 d,
    string e,
  \}
\) \{
  index HashedIndex\(b, c, \) \{
    index FifoIndex\(\) fifo,
  \} primary,
  index FifoIndex\(\) second,
\}/);

$it2 = eval {
	$tt1->findIndexPath();
};
#print STDERR "$@\n";
ok($@ =~ /Triceps::TableType::findIndexPath: idxPath must be an array of non-zero length, table type is:
table \(
  row \{
    uint8 a,
    int32 b,
    int64 c,
    float64 d,
    string e,
  \}
\) \{
  index HashedIndex\(b, c, \) \{
    index FifoIndex\(\) fifo,
  \} primary,
  index FifoIndex\(\) second,
\}/);

{
	# duplicating fields in the nested indexes are not a good idea,
	my $ttDeep = Triceps::TableType->new($rt1)
		->addSubIndex("xab", # for iteration in order grouped by source
			Triceps::IndexType->newHashed(key => [ "a", "b" ])
			->addSubIndex("xbc", 
				Triceps::IndexType->newHashed(key => [ "b", "c" ])
			)
		)
	;
	ok(ref $ttDeep, "Triceps::TableType");
	my ($it, @keys) = eval { $ttDeep->findIndexKeyPath("xab", "xbc"); };
	#print STDERR "$@\n";
	ok($@ =~ /Triceps::TableType::findIndexKeyPath: the path 'xab.xbc' involves the key field 'b' twice, table type is:
table \(
  row {
    uint8 a,
    int32 b,
    int64 c,
    float64 d,
    string e,
  }
\) {
  index HashedIndex\(a, b, \) {
    index HashedIndex\(b, c, \) xbc,
  } xab,
}/);
}

{
	my $ttDeep = Triceps::TableType->new($rt1)
		->addSubIndex("xab", # for iteration in order grouped by source
			Triceps::IndexType->newHashed(key => [ "a", "b" ])
			->addSubIndex("xbc", 
				Triceps::SimpleOrderedIndex->new(
					a => "ASC",
					c => "DESC",
				)
			)
		)
	;
	ok(ref $ttDeep, "Triceps::TableType");
	my ($it, @keys) = eval { $ttDeep->findIndexKeyPath("xab", "xbc"); };
	# print STDERR "$@\n";
	ok($@ =~ /Triceps::TableType::findIndexKeyPath: the index type at path 'xab.xbc' does not have a key, table type is:
table \(
  row {
    uint8 a,
    int32 b,
    int64 c,
    float64 d,
    string e,
  }
\) {
  index HashedIndex\(a, b, \) {
    index PerlSortedIndex\(SimpleOrder a ASC, c DESC, \) xbc,
  } xab,
}/);
}

###################### initialization #################################

$res = $tt1->isInitialized();
ok($res, 0);

$res = $tt1->initialize();
ok($res, 1);
ok($! . "", "");

$res = $tt1->isInitialized();
ok($res, 1);

# repeated initialization is OK
$res = $tt1->initialize();
ok($res, 1);
ok($! . "", "");

# check that still can find indexes
$it2 = $tt1->getFirstLeaf();
$res = $it2->print();
ok($res, "index FifoIndex()");

$res = $it2->getTabtype();
ok(ref $res, "Triceps::TableType");
ok($tt1->same($res));

# adding indexes is not allowed any more
$res = $tt1->addSubIndex("second", Triceps::IndexType->newFifo());
ok(!defined $res);
ok($! . "", "Triceps::TableType::addSubIndex: table is already initialized, can not add indexes any more");

