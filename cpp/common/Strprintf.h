//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Assorted functions working on strings.

#ifndef __Triceps_StringTools_h__
#define __Triceps_StringTools_h__

#include <string>
#include <common/Conf.h>

namespace TRICEPS_NS {

using namespace std;

// like sprintf() but returns a C++ string
string strprintf(const char *fmt, ...)
	__attribute__((format(printf, 1, 2)));


}; // TRICEPS_NS

#endif // __Triceps_StringTools_h__
