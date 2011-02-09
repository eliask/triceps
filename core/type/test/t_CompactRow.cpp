//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of a MtBuffer allocation and destruction.

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

	UT_IS(rt1->print("  ", "  "), 
		"row {\n"
		"    uint8[10] a,\n"
		"    int32[] b,\n"
		"    int64 c,\n"
		"    float64 d,\n"
		"    string e,\n"
		"  }");

	UT_IS(rt1->print(NOINDENT), 
		"row {"
		" uint8[10] a,"
		" int32[] b,"
		" int64 c,"
		" float64 d,"
		" string e,"
		" }");
}

UTESTCASE parse_err(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	fld[0].name_ = "";
	Autoref<RowType> rt2 = new CompactRowType(fld);
	UT_ASSERT(!rt2->getErrors().isNull());
	UT_IS(rt2->getErrors()->print(), "field 1 name must not be empty\n");

	mkfields(fld);
	fld[0].name_ = "c";
	rt2 = new CompactRowType(fld);
	UT_ASSERT(!rt2->getErrors().isNull());
	UT_IS(rt2->getErrors()->print(), "duplicate field name 'c' for fields 3 and 1\n");

	mkfields(fld);
	fld[1].type_ = rt1;
	rt2 = new CompactRowType(fld);
	UT_ASSERT(!rt2->getErrors().isNull());
	UT_IS(rt2->getErrors()->print(), "field 'b' type must be a simple type\n");

	mkfields(fld);
	fld[4].type_ = Type::r_void;
	rt2 = new CompactRowType(fld);
	UT_ASSERT(!rt2->getErrors().isNull());
	UT_IS(rt2->getErrors()->print(), "field 'e' type must not be void\n");
}

UTESTCASE mkrow(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	if (UT_ASSERT(rt1->getErrors().isNull())) return;

	FdataVec dv;
	mkfdata(dv);
	Rowref r1(rt1,  rt1->makeRow(dv));
	for (int i = 0; i < rt1->fieldCount(); i++) {
		if (UT_ASSERT(!rt1->isFieldNull(r1, i))) {
			printf("failed at field %d\n", i);
			fflush(stdout);
			return;
		}
	}

	const char *ptr;
	intptr_t len;
	for (int i = 0; i < rt1->fieldCount(); i++) {
		if ( UT_ASSERT(rt1->getField(r1, i, ptr, len))
		|| UT_IS(len, dv[i].len_)
		|| UT_ASSERT(!memcmp(dv[i].data_, ptr, len)) ) {
			printf("failed at field %d\n", i);
			fflush(stdout);
			char *p = (char *)r1.get();
			hexdump(stdout, p, sizeof(CompactRow)+5*sizeof(int32_t));
			fflush(stdout);
			hexdump(stdout, p, ((CompactRow*)r1.get())->getFieldPtr(rt1->fieldCount())-p);
			fflush(stdout);
			return;
		}
	}

	// try to put a NULL in each of the fields
	for (int j = 0; j < rt1->fieldCount(); j++) {
		mkfdata(dv);
		dv[j].notNull_ = false;
		r1.assign(rt1, rt1->makeRow(dv));
		for (int i = 0; i < rt1->fieldCount(); i++) {
			if (i == j) {
				if ( UT_ASSERT(!rt1->getField(r1, i, ptr, len))
				|| UT_IS(len, 0)) {
					printf("failed at field %d, null in %d\n", i, j);
					fflush(stdout);
					return;
				}
			} else {
				if ( UT_ASSERT(rt1->getField(r1, i, ptr, len))
				|| UT_IS(len, dv[i].len_)
				|| UT_ASSERT(!memcmp(dv[i].data_, ptr, len)) ) {
					printf("failed at field %d, null in %d\n", i, j);
					fflush(stdout);
					char *p = (char *)r1.get();
					hexdump(stdout, p, sizeof(CompactRow)+5*sizeof(int32_t));
					fflush(stdout);
					hexdump(stdout, p, ((CompactRow*)r1.get())->getFieldPtr(rt1->fieldCount())-p);
					fflush(stdout);
					return;
				}
			}
		}
	}
	
	// try to put a NULL in all fields but one
	for (int j = 0; j < rt1->fieldCount(); j++) {
		mkfdata(dv);
		for (int i = 0; i < rt1->fieldCount(); i++) {
			if (i != j)
				dv[i].notNull_ = false;
		}
		r1.assign(rt1, rt1->makeRow(dv));
		for (int i = 0; i < rt1->fieldCount(); i++) {
			if (i != j) {
				if ( UT_ASSERT(!rt1->getField(r1, i, ptr, len))
				|| UT_IS(len, 0)) {
					printf("failed at field %d, null in %d\n", i, j);
					fflush(stdout);
					return;
				}
			} else {
				if ( UT_ASSERT(rt1->getField(r1, i, ptr, len))
				|| UT_IS(len, dv[i].len_)
				|| UT_ASSERT(!memcmp(dv[i].data_, ptr, len)) ) {
					printf("failed at field %d, null in %d\n", i, j);
					fflush(stdout);
					char *p = (char *)r1.get();
					hexdump(stdout, p, sizeof(CompactRow)+5*sizeof(int32_t));
					fflush(stdout);
					hexdump(stdout, p, ((CompactRow*)r1.get())->getFieldPtr(rt1->fieldCount())-p);
					fflush(stdout);
					return;
				}
			}
		}
	}

	// put NULL in all the fields
	mkfdata(dv);
	for (int i = 0; i < rt1->fieldCount(); i++) {
		dv[i].notNull_ = false;
	}
	r1.assign(rt1, rt1->makeRow(dv));
	for (int i = 0; i < rt1->fieldCount(); i++) {
		if ( UT_ASSERT(!rt1->getField(r1, i, ptr, len))
		|| UT_IS(len, 0)) {
			printf("failed at field %d\n", i);
			fflush(stdout);
			return;
		}
	}
}

UTESTCASE mkrowshort(Utest *utest)
{
	// test the auto-filling with NULLs
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	if (UT_ASSERT(rt1->getErrors().isNull())) return;

	FdataVec dv;
	mkfdata(dv);
	dv.resize(1);
	Rowref r1(rt1,  dv);
	if (UT_ASSERT(!rt1->isFieldNull(r1, 0))) return;

	for (int i = 1; i < rt1->fieldCount(); i++) {
		if ( UT_ASSERT(rt1->isFieldNull(r1, i))) {
			printf("failed at field %d\n", i);
			fflush(stdout);
			return;
		}
	}
}

UTESTCASE mkrowover(Utest *utest)
{
	// test the override fields
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	if (UT_ASSERT(rt1->getErrors().isNull())) return;

	FdataVec dv;
	mkfdata(dv);

	dv[0].data_ = 0; // test the zeroing

	Fdata fda;
	fda.setOverride(0, 0, "aa",  2);
	dv.push_back(fda);

	// for the rest, just use constructors
	dv.push_back(Fdata(0, 8, "bb", 2));
	dv.push_back(Fdata(1, -1, "bb", 2));
	dv.push_back(Fdata(2, 0, "bb", -1));
	dv.push_back(Fdata(3, 0, "01234567890123456789", 20));
	dv.push_back(Fdata(4, 0, NULL, 2));

	Rowref r1(rt1);
	r1 =  dv; // makeRow in assignment

	const char *ptr;
	intptr_t len;

	// field 0 will be filled in an interesting way
	if ( UT_ASSERT(rt1->getField(r1, 0, ptr, len))
	|| UT_IS(len, dv[0].len_)
	|| UT_ASSERT(!memcmp("aa\0\0\0\0\0\0bb", ptr, len)) ) {
		char *p = (char *)r1.get();
		hexdump(stdout, p, sizeof(CompactRow)+5*sizeof(int32_t));
		fflush(stdout);
		hexdump(stdout, p, ((CompactRow*)r1.get())->getFieldPtr(rt1->fieldCount())-p);
		fflush(stdout);
		return;
	}

	// the rest of fields should be unchanget
	for (int i = 1; i < rt1->fieldCount(); i++) {
		if ( UT_ASSERT(rt1->getField(r1, i, ptr, len))
		|| UT_IS(len, dv[i].len_)
		|| UT_ASSERT(!memcmp(dv[i].data_, ptr, len)) ) {
			printf("failed at field %d\n", i);
			fflush(stdout);
			char *p = (char *)r1.get();
			hexdump(stdout, p, sizeof(CompactRow)+5*sizeof(int32_t));
			fflush(stdout);
			hexdump(stdout, p, ((CompactRow*)r1.get())->getFieldPtr(rt1->fieldCount())-p);
			fflush(stdout);
			return;
		}
	}
}
