//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of table and intex types creation.

#include <utest/Utest.h>
#include <string.h>

#include <type/AllTypes.h>
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
}


