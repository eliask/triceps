//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of table creation iwth a primary index.

#include <utest/Utest.h>
#include <string.h>

#include <type/AllTypes.h>
#include <common/StringUtil.h>
#include <table/Table.h>
#include <table/PrimaryIndex.h>
#include <mem/Rhref.h>

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

UTESTCASE primaryIndex(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addIndex("primary", new PrimaryIndexType(
			(new NameSet())->add("a")->add("e"))
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable();
	UT_ASSERT(!t.isNull());

#if 0
	// XXX needs to be rewritten with correct logic
	
	Index *prim = t->findIndex("primary");
	UT_ASSERT(prim != NULL);
	UT_IS(t->findIndexByType(IndexType::IT_PRIMARY), prim);

	UT_IS(t->findIndexByType(IndexType::IT_LAST), NULL);
	UT_IS(t->findIndex("nosuch"), NULL);

	UT_IS(prim->findIndex("nosuch"), NULL);
	UT_IS(prim->findIndexByType(IndexType::IT_LAST), NULL);
#endif
}

UTESTCASE uninitialized(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addIndex("primary", new PrimaryIndexType(
			(new NameSet())->add("a")->add("e"))
		);

	UT_ASSERT(tt);

	Autoref<Table> t = tt->makeTable();
	UT_ASSERT(t.isNull());
}

UTESTCASE withError(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addIndex("primary", new PrimaryIndexType(
			(new NameSet())->add("x")->add("e"))
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(!tt->getErrors().isNull());
	UT_ASSERT(tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable();
	UT_ASSERT(t.isNull());
}

UTESTCASE tableops(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addIndex("primary", new PrimaryIndexType(
			(new NameSet())->add("a")->add("e"))
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable();
	UT_ASSERT(!t.isNull());

#if 0 // XXX
	Index *prim = t->findIndex("primary");
	UT_ASSERT(prim != NULL);
#endif

	// above here was a copy of primaryIndex()

	RowHandle *iter;
	FdataVec dv;
	mkfdata(dv);
	Rowref r1(rt1,  rt1->makeRow(dv));
	Rhref rh1(t, t->makeRowHandle(r1));

	// so far the table must be empty
	iter = t->begin();
	UT_IS(iter, NULL);

	// basic insertion
	UT_ASSERT(t->insert(rh1));
	iter = t->begin();
	UT_IS(iter, rh1);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// this should replace the row with an identical one but with auto-created handle
	UT_ASSERT(t->insert(r1));
	iter = t->begin();
	// RowHandle *iter2 = iter;
	UT_ASSERT(iter != NULL);
	UT_ASSERT(iter != rh1);
	iter = t->next(iter);
	UT_IS(iter, NULL);

#if 0 // XXX
	// check that the newly inserted record can be found by find on the same key
	iter = prim->find(rh1);
	UT_ASSERT(iter == iter2);
#endif

	// check that iteration with NULL doesn't crash
	UT_ASSERT(t->next(NULL) == NULL);

	// add 2nd record
	const char *key2 = "key2";
	dv[4].setPtr(true, key2, sizeof(key2));
	Rowref r2(rt1, rt1->makeRow(dv));

	UT_ASSERT(t->insert(r2));

	// check that now have 2 records
	iter = t->begin();
	UT_ASSERT(iter != NULL);
	iter = t->next(iter);
	UT_ASSERT(iter != NULL);
	iter = t->next(iter);
	UT_ASSERT(iter == NULL);

	// add 3rd record
	const char *key3 = "key3";
	dv[4].setPtr(true, key3, sizeof(key3));
	Rowref r3(rt1, rt1->makeRow(dv));

	UT_ASSERT(t->insert(r3));

	// check that now have 3 records
	iter = t->begin();
	UT_ASSERT(iter != NULL);
	iter = t->next(iter);
	UT_ASSERT(iter != NULL);
	iter = t->next(iter);
	UT_ASSERT(iter != NULL);
	iter = t->next(iter);
	UT_ASSERT(iter == NULL);

#if 0 // XXX
	// find and remove the 1st record
	iter = prim->find(rh1);
	UT_ASSERT(iter != NULL);
	t->remove(iter);

	// check that the record is not there any more
	iter = prim->find(rh1);
	UT_ASSERT(iter == NULL);

	// check that now have 2 records
	iter = t->begin();
	UT_ASSERT(iter != NULL);
	iter = t->next(iter);
	UT_ASSERT(iter != NULL);
	iter = t->next(iter);
	UT_ASSERT(iter == NULL);
#endif
}

