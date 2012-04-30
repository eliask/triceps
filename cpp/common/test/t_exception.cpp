//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the exceptions.

#include <utest/Utest.h>

#include <signal.h>
#include <setjmp.h>
#include <common/Exception.h>


UTESTCASE throw_catch(Utest *utest)
{
	UT_IS(Exception::abort_, true); // the default
	Exception::abort_ = false;
	UT_IS(Exception::abort_, false);

	try {
		throw Exception("message");
	} catch (Exception e) {
		string what = e.what();
		UT_IS(what, "message\n");
	}

	try {
		Erref err = new Errors;
		err->appendMsg(true, "message");
		throw Exception(err);
	} catch (Exception e) {
		Erref err = e.getErrors();
		string what;
		err->printTo(what);
		UT_IS(what, "message\n");
	}

	Exception::abort_ = true; // restore back
}

bool aborted;

UTESTCASE abort(Utest *utest)
{
	Exception::__testAbort_ = &aborted; // prevent the abort

	UT_IS(Exception::abort_, true); // the default

	aborted = false;
	try {
		throw Exception("test of an abort message");
	} catch (Exception e) {
	}
	UT_ASSERT(aborted);

	aborted = false;
	try {
		Erref err = new Errors;
		err->appendMsg(true, "test of an abort message");
		throw Exception(err);
	} catch (Exception e) {
	}
	UT_ASSERT(aborted);
}
