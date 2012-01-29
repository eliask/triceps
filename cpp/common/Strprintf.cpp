//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Assorted functions working on strings.

#include <common/Strprintf.h>
#include <stdarg.h>
#include <stdio.h>

namespace TRICEPS_NS {

string strprintf(const char *fmt, ...)
{
	char buf[500];
	va_list ap;

	va_start(ap, fmt);
	int n = vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	if (n < sizeof(buf))
		return string(buf);

	// a more complicated case, with a large string
	char *s = new char[n+1];
	va_start(ap, fmt);
	vsnprintf(s, n+1, fmt, ap);
	va_end(ap);
	string ret(s);
	delete[] s;
	return ret;
}

}; // TRICEPS_NS
