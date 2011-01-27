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

UTESTCASE findSimpleType(Utest *utest)
{
	UT_ASSERT(Type::findSimpleType("float64") == Type::r_float64);
	UT_ASSERT(Type::findSimpleType("int32") == Type::r_int32);
	UT_ASSERT(Type::findSimpleType("int64") == Type::r_int64);
	UT_ASSERT(Type::findSimpleType("string") == Type::r_string);
	UT_ASSERT(Type::findSimpleType("uint8") == Type::r_uint8);
	UT_ASSERT(Type::findSimpleType("void") == Type::r_void);

	UT_ASSERT(Type::findSimpleType("int33").isNull());

	UT_ASSERT(!Type::findSimpleType("int32").isNull());
}

