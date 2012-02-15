//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of table and index types creation.

#include <utest/Utest.h>
#include <string.h>

#include <type/AllTypes.h>
#include <sched/AggregatorGadget.h>
#include <common/StringUtil.h>

// Make fields of all simple types
void mkfields(RowType::FieldVec &fields)
{
	fields.clear();
	fields.push_back(RowType::Field("a", Type::r_uint8, 10));
	fields.push_back(RowType::Field("b", Type::r_int32,0));
	fields.push_back(RowType::Field("c", Type::r_int64));
	fields.push_back(RowType::Field("d", Type::r_float64));
	fields.push_back(RowType::Field("e", Type::r_string));
}

uint8_t v_uint8[10] = "123456789";
int32_t v_int32 = 1234;
int64_t v_int64 = 0xdeadbeefc00c;
double v_float64 = 9.99e99;
char v_string[] = "hello world";

void mkfdata(FdataVec &fd)
{
	fd.resize(4);
	fd[0].setPtr(true, &v_uint8, sizeof(v_uint8));
	fd[1].setPtr(true, &v_int32, sizeof(v_int32));
	fd[2].setPtr(true, &v_int64, sizeof(v_int64));
	fd[3].setPtr(true, &v_float64, sizeof(v_float64));
	// test the constructor
	fd.push_back(Fdata(true, &v_string, sizeof(v_string)));
}

UTESTCASE emptyTable(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = new TableType(rt1);

	UT_ASSERT(tt);
	UT_IS(tt->getFirstLeaf(), NULL);

	tt->initialize();
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "no indexes are defined\n");
}

UTESTCASE hashedIndex(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", new HashedIndexType(
			(new NameSet())->add("a")->add("e"))
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	// repeated initialization should be fine
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index HashedIndex(a, e, ) primary,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index HashedIndex(a, e, ) primary, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("primary");
	UT_ASSERT(prim != NULL);
	UT_IS(tt->findSubIndexById(IndexType::IT_HASHED), prim);
	UT_IS(tt->getFirstLeaf(), prim);

	Autoref<NameSet> expectKey = (new NameSet())->add("a")->add("e");
	const_Autoref<NameSet> getKey = prim->getKey();
	UT_ASSERT(getKey->equals(expectKey));

	UT_IS(tt->findSubIndexById(IndexType::IT_LAST), NULL);
	UT_IS(tt->findSubIndex("nosuch"), NULL);

	UT_IS(prim->findSubIndex("nosuch"), NULL);
	UT_IS(prim->findSubIndex("nosuch")->findSubIndex("nothat"), NULL);
	UT_IS(prim->findSubIndexById(IndexType::IT_LAST), NULL);
	UT_IS(prim->findSubIndex("nosuch")->findSubIndexById(IndexType::IT_LAST), NULL);
}

UTESTCASE badRow(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);
	fld[1].name_ = "a"; // duplicate field name

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors()->hasError());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", new HashedIndexType(
			(new NameSet())->add("a")->add("e"))
		);

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "row type error:\n  duplicate field name 'a' for fields 2 and 1\n");
}

UTESTCASE nullRow(Utest *utest)
{
	Autoref<TableType> tt = (new TableType(NULL))
		->addSubIndex("primary", new HashedIndexType(
			(new NameSet())->add("a")->add("e"))
		);

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "the row type is not set\n");
}

UTESTCASE badIndexName(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("", new HashedIndexType(
			(new NameSet())->add("a")->add("e"))
		);

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "index error:\n  nested index 1 is not allowed to have an empty name\n");
}

UTESTCASE nullIndex(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", NULL)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "index error:\n  nested index 1 'primary' reference must not be NULL\n");
}

UTESTCASE dupIndexName(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", new HashedIndexType(
			(new NameSet())->add("a")->add("e"))
		)
		->addSubIndex("primary", new HashedIndexType(
			(new NameSet())->add("a")->add("e"))
		)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "index error:\n  nested index 2 name 'primary' is used more than once\n");
}

UTESTCASE hashedNested(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", (new HashedIndexType(
			(new NameSet())->add("a")->add("e")))
			->addSubIndex("level2", new HashedIndexType(
				(new NameSet())->add("a")->add("e"))
			)
		)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(tt->getErrors().isNull()))
		return;
	
	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index HashedIndex(a, e, ) {\n"
		"    index HashedIndex(a, e, ) level2,\n"
		"  } primary,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index HashedIndex(a, e, ) { index HashedIndex(a, e, ) level2, } primary, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("primary");
	if (UT_ASSERT(prim != NULL))
		return;
	UT_IS(tt->findSubIndexById(IndexType::IT_HASHED), prim);

	IndexType *sec = prim->findSubIndex("level2");
	if (UT_ASSERT(sec != NULL))
		return;
	UT_IS(prim->getTabtype(), tt);
	UT_IS(prim->findSubIndexById(IndexType::IT_HASHED), sec);

	UT_IS(sec->findSubIndex("nosuch"), NULL);
	UT_IS(sec->findSubIndexById(IndexType::IT_LAST), NULL);
}

UTESTCASE hashedBadField(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", new HashedIndexType(
			(new NameSet())->add("x")->add("e"))
		)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "index error:\n  nested index 1 'primary':\n    can not find the key field 'x'\n");
}

UTESTCASE fifoIndex(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("fifo", new FifoIndexType()
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	// repeated initialization should be fine
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index FifoIndex() fifo,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index FifoIndex() fifo, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("fifo");
	UT_ASSERT(prim != NULL);
	UT_IS(tt->findSubIndexById(IndexType::IT_FIFO), prim);

	const_Autoref<NameSet> getKey = prim->getKey();
	UT_ASSERT(getKey.isNull());
}

UTESTCASE fifoIndexLimit(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("fifo", new FifoIndexType(15)
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	// repeated initialization should be fine
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index FifoIndex(limit=15) fifo,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index FifoIndex(limit=15) fifo, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("fifo");
	UT_ASSERT(prim != NULL);
	UT_IS(tt->findSubIndexById(IndexType::IT_FIFO), prim);
}

UTESTCASE fifoIndexJumping(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<FifoIndexType> it0 = FifoIndexType::make(15, true);
	UT_ASSERT(it0);
	UT_ASSERT(it0->isJumping());

	Autoref<FifoIndexType> it0cp = dynamic_cast<FifoIndexType*>(it0->copy());
	UT_ASSERT(it0cp->isJumping());

	it0->setJumping(false);
	UT_ASSERT(!it0->isJumping());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("fifo", new FifoIndexType(15, true)
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	// repeated initialization should be fine
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index FifoIndex(limit=15 jumping) fifo,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index FifoIndex(limit=15 jumping) fifo, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("fifo");
	UT_ASSERT(prim != NULL);
	UT_IS(tt->findSubIndexById(IndexType::IT_FIFO), prim);
}

UTESTCASE fifoIndexReverse(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<FifoIndexType> it0 = FifoIndexType::make(0, false, true);
	UT_ASSERT(it0);
	UT_ASSERT(it0->isReverse());

	Autoref<FifoIndexType> it0cp = dynamic_cast<FifoIndexType*>(it0->copy());
	UT_ASSERT(it0cp->isReverse());

	it0->setReverse(false);
	UT_ASSERT(!it0->isReverse());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("fifo", new FifoIndexType(0, false, true)
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	// repeated initialization should be fine
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index FifoIndex( reverse) fifo,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index FifoIndex( reverse) fifo, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("fifo");
	UT_ASSERT(prim != NULL);
	UT_IS(tt->findSubIndexById(IndexType::IT_FIFO), prim);
}

UTESTCASE fifoBadJumping(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("fifo", new FifoIndexType(0, true)
		)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "index error:\n  nested index 1 'fifo':\n    FifoIndexType requires a non-0 limit for the jumping mode\n");
}

UTESTCASE fifoBadNested(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("fifo", (new FifoIndexType())
			->addSubIndex("level2", new HashedIndexType(
				(new NameSet())->add("a")->add("e"))
			)
		)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(!tt->getErrors().isNull()))
		return;
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "index error:\n  nested index 1 'fifo':\n    FifoIndexType currently does not support further nested indexes\n");
}

class MySortCondition : public SortedIndexCondition
{
public:
	// @param returnError - flag: return an initialization error for testing
	MySortCondition(bool returnError) :
		returnError_(returnError)
	{ }

	virtual void initialize(Erref &errors, TableType *tabtype, SortedIndexType *indtype)
	{
		if (rt_.isNull())
			errors->appendMsg(true, "Uninitialized rt_");
		if (returnError_) {
			errors->appendMsg(true, "A test error");
		} else {
			SortedIndexCondition::initialize(errors, tabtype, indtype);
		}
	}

	// no internal configuration, all copies are the same
	virtual bool equals(const SortedIndexCondition *sc) const
	{
		return true;
	}
	virtual bool match(const SortedIndexCondition *sc) const
	{
		return true;
	}
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const
	{
		res.append("MySorted()");
	}
	virtual SortedIndexCondition *copy() const
	{
		return new MySortCondition(*this);
	}

	virtual bool operator() (const RowHandle *r1, const RowHandle *r2) const
	{
		return (r1 < r2); // really just a placeholder, not a valid comparison
	}

	bool returnError_;
};

UTESTCASE sortedIndex(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<IndexType> it = new SortedIndexType(new MySortCondition(false));
	UT_ASSERT(it);
	Autoref<IndexType> itcopy = it->copy();
	UT_ASSERT(itcopy);
	UT_ASSERT(it != itcopy);

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", it
		)->addSubIndex("secondary", itcopy
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	// repeated initialization should not be an issue
	tt->initialize();
	UT_ASSERT(!tt->getErrors()->hasError());

	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index MySorted() primary,\n"
		"  index MySorted() secondary,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index MySorted() primary, index MySorted() secondary, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("primary");
	UT_ASSERT(prim != NULL);
	UT_IS(tt->findSubIndexById(IndexType::IT_SORTED), prim);
	UT_IS(tt->getFirstLeaf(), prim);
	UT_IS(tt->findSubIndexById(IndexType::IT_HASHED), NULL);
}

UTESTCASE sortedIndexBad(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", new SortedIndexType(new MySortCondition(true))
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(!tt->getErrors().isNull());
	UT_ASSERT(tt->getErrors()->hasError());

	UT_IS(tt->getErrors()->print(), 
		"index error:\n"
		"  nested index 1 'primary':\n"
		"    A test error\n");
}

UTESTCASE sortedNested(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", (new SortedIndexType(new MySortCondition(false)))
			->addSubIndex("level2", new HashedIndexType(
				(new NameSet())->add("a")->add("e"))
			)
		)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(tt->getErrors().isNull()))
		return;
	
	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index MySorted() {\n"
		"    index HashedIndex(a, e, ) level2,\n"
		"  } primary,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index MySorted() { index HashedIndex(a, e, ) level2, } primary, }");

	// get back the initialized types
	IndexType *prim = tt->findSubIndex("primary");
	if (UT_ASSERT(prim != NULL))
		return;
	UT_IS(tt->findSubIndexById(IndexType::IT_SORTED), prim);

	IndexType *sec = prim->findSubIndex("level2");
	if (UT_ASSERT(sec != NULL))
		return;
	UT_IS(prim->getTabtype(), tt);
	UT_IS(prim->findSubIndexById(IndexType::IT_HASHED), sec);
}

void dummyAggregator(Table *table, AggregatorGadget *gadget, Index *index,
        const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
		Aggregator::AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
{
}

void dummyAggregator2(Table *table, AggregatorGadget *gadget, Index *index,
        const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
		Aggregator::AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
{
}

// derive a separate aggregator type, for comparisons
class MyAggregator : public Aggregator
{
public:
	virtual void handle(Table *table, AggregatorGadget *gadget, Index *index,
		const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
		AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
	{ }
};

class MyAggregatorType : public AggregatorType
{
public:
	// @param name - name for aggregators' gadget in the table, will be tablename.name
	// @param rt - type of rows produced by this aggregator, wil be referenced
	MyAggregatorType(const string &name, const RowType *rt):
		AggregatorType(name, rt)
	{ }

	// from AggregatorType
	virtual AggregatorType *copy() const
	{
		return new MyAggregatorType(*this);
	}
	virtual AggregatorGadget *makeGadget(Table *table, IndexType *intype) const
	{
		return new AggregatorGadget(this, table, intype);
	}
	virtual Aggregator *makeAggregator(Table *table, AggregatorGadget *gadget) const
	{
		return new MyAggregator();
	}
};


UTESTCASE aggregator(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	mkfields(fld);
	fld[0].name_="x";
	Autoref<RowType> rt2 = new CompactRowType(fld);
	UT_ASSERT(rt2->getErrors().isNull());

	mkfields(fld);
	fld[0].type_ = Type::r_int32;
	Autoref<RowType> rt3 = new CompactRowType(fld);
	UT_ASSERT(rt3->getErrors().isNull());

	Autoref<AggregatorType> agt1 = new BasicAggregatorType("onPrimary", rt1, dummyAggregator);
	
	// first check the comparisons of aggregators
	// equals
	{
		UT_ASSERT(agt1->equals(agt1));
		UT_ASSERT(agt1->match(agt1));
	}
	{
		Autoref<AggregatorType> agt2 = agt1->copy();
		UT_ASSERT(agt1->equals(agt2));
		UT_ASSERT(agt1->match(agt2));
	}
	{
		Autoref<AggregatorType> agt2 = new BasicAggregatorType("onPrimary", rt1, dummyAggregator);
		UT_ASSERT(agt1->equals(agt2));
		UT_ASSERT(agt1->match(agt2));
	}
	// matches
	{
		Autoref<AggregatorType> agt2 = new BasicAggregatorType("Primary", rt1, dummyAggregator);
		UT_ASSERT(!agt1->equals(agt2));
		UT_ASSERT(agt1->match(agt2));
	}
	{
		Autoref<AggregatorType> agt2 = new BasicAggregatorType("onPrimary", rt2, dummyAggregator);
		UT_ASSERT(!agt1->equals(agt2));
		UT_ASSERT(agt1->match(agt2));
	}
	// non-matches
	{
		Autoref<AggregatorType> agt2 = new BasicAggregatorType("onPrimary", rt3, dummyAggregator);
		UT_ASSERT(!agt1->equals(agt2));
		UT_ASSERT(!agt1->match(agt2));
	}
	{
		Autoref<AggregatorType> agt2 = new BasicAggregatorType("onPrimary", rt1, dummyAggregator2);
		UT_ASSERT(!agt1->equals(agt2));
		UT_ASSERT(!agt1->match(agt2));
	}
	{
		Autoref<AggregatorType> agt2 = new MyAggregatorType("onPrimary", rt1);
		UT_ASSERT(!agt1->equals(agt2));
		UT_ASSERT(!agt1->match(agt2));
	}

	// check the comparisons of types with aggregators
	Autoref<IndexType> it1 = HashedIndexType::make(
			(new NameSet())->add("a")->add("e"));
	
	// equals and basic presence of aggregator type
	Autoref<IndexType> it2 = it1->copy();
	UT_ASSERT(it1->equals(it2));
	UT_ASSERT(it1->match(it2));

	it1->setAggregator(agt1);
	UT_ASSERT(!it1->equals(it2));
	UT_ASSERT(!it1->match(it2));

	it2->setAggregator(agt1);
	UT_ASSERT(it1->equals(it2));
	UT_ASSERT(it1->match(it2));

	it2->setAggregator(NULL);
	UT_ASSERT(!it1->equals(it2));
	UT_ASSERT(!it1->match(it2));

	// matches
	it2->setAggregator(new BasicAggregatorType("Primary", rt1, dummyAggregator));
	UT_ASSERT(!it1->equals(it2));
	UT_ASSERT(it1->match(it2));

	it2->setAggregator(new BasicAggregatorType("onPrimary", rt2, dummyAggregator));
	UT_ASSERT(!it1->equals(it2));
	UT_ASSERT(it1->match(it2));

	// non-match
	it2->setAggregator(new MyAggregatorType("onPrimary", rt1));
	UT_ASSERT(!it1->equals(it2));
	UT_ASSERT(!it1->match(it2));

	// now build the table type
	Autoref<TableType> tt = (new TableType(rt1))
		->addSubIndex("primary", (new HashedIndexType(
			(new NameSet())->add("a")->add("e")))
			->setAggregator(agt1)
			->addSubIndex("level2", new HashedIndexType(
				(new NameSet())->add("a")->add("e"))
			)
		)
		;

	UT_ASSERT(tt);
	tt->initialize();
	if (UT_ASSERT(tt->getErrors().isNull()))
		return;
	
	IndexType *prim = tt->findSubIndex("primary");
	UT_ASSERT(prim != NULL);
	const AggregatorType *agt2 = prim->getAggregator();
	UT_ASSERT(agt2 != NULL);
	UT_ASSERT(agt2 != agt1.get()); // it must have been copied when set

	const char *expectAgg = 
		"aggregator (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") onPrimary"
	;

	if (UT_ASSERT(agt2->print() == expectAgg)) {
		printf("---Expected:---\n%s\n", expectAgg);
		printf("---Received:---\n%s\n", agt2->print().c_str());
		printf("---\n");
		fflush(stdout);
	}

	const char *expect =
		"table (\n"
		"  row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }\n"
		") {\n"
		"  index HashedIndex(a, e, ) {\n"
		"    index HashedIndex(a, e, ) level2,\n"
		"  } {\n"
		"    aggregator (\n"
		"      row {\n"
		"        uint8[10] a,\n"
		"        int32[] b,\n"
		"        int64 c,\n"
		"        float64 d,\n"
		"        string e,\n"
		"      }\n"
		"    ) onPrimary\n"
		"  } primary,\n"
		"}"
	;
	if (UT_ASSERT(tt->print() == expect)) {
		printf("---Expected:---\n%s\n", expect);
		printf("---Received:---\n%s\n", tt->print().c_str());
		printf("---\n");
		fflush(stdout);
	}
	UT_IS(tt->print(NOINDENT), "table ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) { index HashedIndex(a, e, ) { index HashedIndex(a, e, ) level2, } { aggregator ( row { uint8[10] a, int32[] b, int64 c, float64 d, string e, } ) onPrimary } primary, }");

}

