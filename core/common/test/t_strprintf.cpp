//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of strprintf().

#include <stdio.h>
#include <common/Strprintf.h>

using namespace BICEPS_NS;

bool eCode = 0;

void fail()
{
	eCode = 1;
}

// returns the shell error code
int getCode()
{
	return eCode;
}

int main()
{
	std::string a = strprintf("%s", "aa");
	std::string b = strprintf("%1000s", "bc");

	if (a.size() !=2 || b.size() != 1000)
		fail();

	return getCode();
}
