//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Assorted functions working on strings.

#ifndef __StringTools_h__
#define __StringTools_h__

#include <string>

namespace Biceps {

using namespace std;

// like sprintf() but returns a C++ string
string strprintf(const char *fmt, ...)
	__attribute__((format(printf, 1, 2)));


}; // Biceps

#endif // __StringTools_h__
