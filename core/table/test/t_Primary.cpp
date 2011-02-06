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

	Index *prim = t->findIndex("primary");
	UT_ASSERT(prim != NULL);
	UT_IS(t->findIndexByType(IndexType::IT_PRIMARY), prim);

	UT_IS(t->findIndexByType(IndexType::IT_LAST), NULL);
	UT_IS(t->findIndex("nosuch"), NULL);

	UT_IS(prim->findIndex("nosuch"), NULL);
	UT_IS(prim->findIndexByType(IndexType::IT_LAST), NULL);
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
