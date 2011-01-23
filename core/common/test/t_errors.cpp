//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of strprintf().

#include <utest/Utest.h>

#include <common/Errors.h>

// Now, this is a bit funny, since strprintf() is used inside the etst infrastructure
// too. But if it all works, it should be all good.

UTESTCASE simple(Utest *utest)
{
	Erref e1 = new Errors;
	UT_ASSERT(e1->isEmpty());
	UT_ASSERT(!e1->hasError());

	e1->appendMsg(false, "msg1");
	UT_ASSERT(!e1->isEmpty());
	UT_ASSERT(!e1->hasError());

	e1->appendMsg(true, "msg2");
	UT_ASSERT(!e1->isEmpty());
	UT_ASSERT(e1->hasError());

	Erref e2 = new Errors(true);
	UT_ASSERT(e2->isEmpty());
	UT_ASSERT(e2->hasError());

	string s;
	s = e1->print();
	if (UT_ASSERT(s == "msg1\nmsg2\n")) {
		printf("s=\"%s\"\n", s.c_str());
		fflush(stdout);
	}
	s = e2->print();
	if (UT_ASSERT(s == "")) {
		printf("s=\"%s\"\n", s.c_str());
		fflush(stdout);
	}
}

UTESTCASE nested(Utest *utest)
{
	Erref e1 = new Errors;

	e1->appendMsg(false, "msg1");
	UT_ASSERT(!e1->hasError());

	Erref e2 = new Errors;
	UT_ASSERT(e2->isEmpty());
	UT_ASSERT(!e2->hasError());

	e2->append(e1);
	UT_ASSERT(!e2->isEmpty());
	UT_ASSERT(!e2->hasError());
	UT_ASSERT(e2->cfirst_ ==  e1);
	UT_ASSERT(e2->clast_ ==  e1);

	string s;

	s = e2->print();
	if (UT_ASSERT(s == "  msg1\n")) {
		printf("s=\"%s\"\n", s.c_str());
		fflush(stdout);
	}

	e2->append(new Errors);
	// empty child should get thrown away
	UT_ASSERT(!e2->hasError());
	UT_ASSERT(e2->cfirst_ ==  e1);
	UT_ASSERT(e2->clast_ ==  e1);
	UT_ASSERT(e1->sibling_.isNull());

	e2->append(new Errors(true));
	// empty child should get thrown away, except for error indication
	UT_ASSERT(e2->hasError());
	UT_ASSERT(e2->cfirst_ ==  e1);
	UT_ASSERT(e2->clast_ ==  e1);

	Erref e3 = new Errors;
	e3->appendMsg(true, "msg3");
	e2->append(e3);
	UT_ASSERT(e2->cfirst_ ==  e1);
	UT_ASSERT(e2->clast_ ==  e3);
	UT_ASSERT(e1->sibling_ ==  e3);
	UT_ASSERT(e3->sibling_.isNull());

	s = e2->print();
	if (UT_ASSERT(s == "  msg1\n  msg3\n")) {
		printf("s=\"%s\"\n", s.c_str());
		fflush(stdout);
	}

	Erref e4 = new Errors;
	e4->append(e2);
	UT_ASSERT(e4->hasError());

	e4->appendMsg(true, "msg4");
	s = e4->print();
	if (UT_ASSERT(s == "msg4\n    msg1\n    msg3\n")) {
		printf("s=\"%s\"\n", s.c_str());
		fflush(stdout);
	}
}
