//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of strprintf().

#include <utest/Utest.h>

#include <common/Strprintf.h>

// Now, this is a bit funny, since strprintf() is used inside the etst infrastructure
// too. But if it all works, it should be all good.

UTESTCASE mkshort(Utest *utest)
{
	std::string s = strprintf("%s", "aa");
	UT_ASSERT(s.size() == 2);
}

UTESTCASE mklong(Utest *utest)
{
	std::string s = strprintf("%1000s", "bc");
	UT_ASSERT(s.size() == 1000);
}
