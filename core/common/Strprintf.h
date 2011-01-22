//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Assorted functions working on strings.

#ifndef __Biceps_StringTools_h__
#define __Biceps_StringTools_h__

#include <string>
#include <common/Conf.h>

namespace BICEPS_NS {

using namespace std;

// like sprintf() but returns a C++ string
string strprintf(const char *fmt, ...)
	__attribute__((format(printf, 1, 2)));


}; // BICEPS_NS

#endif // __Biceps_StringTools_h__
