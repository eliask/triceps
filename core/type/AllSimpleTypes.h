//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Collection of headers for all the simple types.

#ifndef __Biceps_AllSimpleTypes_h__
#define __Biceps_AllSimpleTypes_h__

#include <common/Common.h>
#include <type/SimpleType.h>

namespace BICEPS_NS {

// Later, when there will be own language, these definitions may become
// more complex and be split into their separate files.

class VoidType : public SimpleType
{
public:
	VoidType() :
		SimpleType(TT_VOID, 0) // should Void even be a simple type?
	{ }
};

class Uint8Type : public SimpleType
{
public:
	Uint8Type() :
		SimpleType(TT_UINT8, 1)
	{ }
};

class Int32Type : public SimpleType
{
public:
	Int32Type() :
		SimpleType(TT_INT32, sizeof(int32_t))
	{ }
};

class Int64Type : public SimpleType
{
public:
	Int64Type() :
		SimpleType(TT_INT64, sizeof(int64_t))
	{ }
};

class Float64Type : public SimpleType
{
public:
	Float64Type() :
		SimpleType(TT_FLOAT64, sizeof(double))
	{ }
};

class StringType : public SimpleType
{
public:
	// string is not really a simple type, it's an array of uint8, with an extra \0 added
	StringType() :
		SimpleType(TT_STRING, 1)
	{ }
};

}; // BICEPS_NS

#endif // __Biceps_AllSimpleTypes_h__

