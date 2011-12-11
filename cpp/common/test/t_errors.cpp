//
// (C) Copyright 2011 Sergey A. Babkin.
// This file is a part of Triceps.
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

	UT_IS(e1->print(), "msg1\nmsg2\n");
	UT_IS(e2->print(), "");

	e1->clear();
	UT_ASSERT(!e1->hasError());
	UT_IS(e1->print(), "");
}

UTESTCASE nested(Utest *utest)
{
	Erref e1 = new Errors;

	e1->appendMsg(false, "msg1");
	UT_ASSERT(!e1->hasError());
	UT_ASSERT(!e1->isEmpty());

	Erref e2 = new Errors;
	UT_ASSERT(e2->isEmpty());
	UT_ASSERT(!e2->hasError());

	UT_ASSERT(e2->append("from e1", e1) == true);
	UT_ASSERT(!e2->isEmpty());
	UT_ASSERT(!e2->hasError());

	UT_IS(e2->print(), "from e1\n  msg1\n");

	UT_ASSERT(e2->append("add empty", new Errors) == false);
	// empty child should get thrown away
	UT_ASSERT(!e2->hasError());
	UT_IS(e2->elist_.size(), 1);

	UT_ASSERT(e2->append("", new Errors(true)) == true);
	// empty child should get thrown away, except for error indication
	UT_ASSERT(e2->hasError());
	UT_IS(e2->elist_.size(), 2);
	UT_ASSERT(e2->elist_[1].child_.isNull());

	e2->replaceMsg("child error flag");
	UT_IS(e2->elist_[1].msg_, "child error flag");

	Erref e3 = new Errors;
	e3->appendMsg(true, "msg3");
	UT_ASSERT(e2->append("from e3", e3) == true);

	UT_IS(e2->print(), "from e1\n  msg1\nchild error flag\nfrom e3\n  msg3\n");

	Erref e4 = new Errors;
	UT_ASSERT(e4->append("from e2", e2) == true);
	UT_ASSERT(e4->hasError());

	e4->appendMsg(true, "msg4");
	UT_IS(e4->print(), "from e2\n  from e1\n    msg1\n  child error flag\n  from e3\n    msg3\nmsg4\n");
}
