//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Collection of definitions for all the simple types.

#include <type/AllSimpleTypes.h>

namespace BICEPS_NS {

void VoidType::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("void");
}

void Uint8Type::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("uint8");
}

void Int32Type::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("int32");
}

void Int64Type::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("int64");
}

void Float64Type::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("float64");
}

void StringType::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("string");
}

}; // BICEPS_NS
