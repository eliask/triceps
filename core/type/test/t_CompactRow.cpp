//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of a MtBuffer allocation and destruction.

#include <utest/Utest.h>

#include <type/AllTypes.h>

// Make fields of all simple types
void mkfields(RowType::FieldVec &fields)
{
	fields.clear();
	fields.push_back(RowType::Field("a", Type::r_uint8, 10));
	fields.push_back(RowType::Field("b", Type::r_int32));
	fields.push_back(RowType::Field("c", Type::r_int64));
	fields.push_back(RowType::Field("d", Type::r_float64));
	fields.push_back(RowType::Field("e", Type::r_string));
}

UTESTCASE rowtype(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());
	
	Autoref<RowType> rt2 = new CompactRowType(rt1);
	UT_ASSERT(rt2->getErrors().isNull());

	UT_ASSERT(rt1->equals(rt2));
	UT_ASSERT(rt2->equals(rt1));
	UT_ASSERT(rt1->match(rt2));
	UT_ASSERT(rt2->match(rt1));

	fld[0].name_ = "aa";
	Autoref<RowType> rt3 = rt1->newSameFormat(fld);
	UT_ASSERT(rt3->getErrors().isNull());

	UT_ASSERT(rt1->fields()[0].name_ == "a");
	UT_IS(rt3->fields()[0].name_, "aa");

	UT_ASSERT(!rt1->equals(rt3));
	UT_ASSERT(!rt3->equals(rt1));
	UT_ASSERT(rt1->match(rt3));
	UT_ASSERT(rt3->match(rt1));

	UT_IS(rt1->fieldCount(), fld.size());
	UT_IS(rt1->findIdx("b"), 1);
	UT_IS(rt1->findIdx("aa"), -1);
	UT_IS(rt1->find("b"), &rt1->fields()[1]);
	UT_IS(rt1->find("aa"), NULL);
}

