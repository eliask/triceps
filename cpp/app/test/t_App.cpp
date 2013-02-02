//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the App building.

#include <utest/Utest.h>
#include <app/App.h>
#include <app/TrieadOwner.h>

// Access to the protected internals of App.
class AppGuts: public App
{
public:
	static void gutsWaitReady(App *a)
	{
		AppGuts *ag = ((AppGuts *)a);
		return ag->waitReady();
	}
};

// make the exceptions catchable
void make_catchable()
{
	Exception::abort_ = false; // make them catchable
	Exception::enableBacktrace_ = false; // make the error messages predictable
}

// restore the exceptions back to the uncatchable state
void restore_uncatchable()
{
	Exception::abort_ = true;
	Exception::enableBacktrace_ = true;
}

UTESTCASE statics(Utest *utest)
{
	make_catchable();

	// construction
	Autoref<App> a1 = App::make("a1");
	Autoref<App> a2 = App::make("a2");

	// successfull find
	Autoref<App> a;
	a = App::find("a1");
	UT_IS(a, a1);
	a = App::find("a2");
	UT_IS(a, a2);

	// list
	App::Map amap;
	App::getList(amap);
	UT_IS(amap.size(), 2);
	UT_IS(amap["a1"], a1);
	UT_IS(amap["a2"], a2);

	// check that the old map gets cleared on the call
	App::getList(amap);
	UT_IS(amap.size(), 2);

	// drop
	App::drop(a2);
	App::getList(amap);
	UT_IS(amap.size(), 1);
	
	// unsuccessfull make
	{
		string msg;
		try {
			a = App::make("a1");
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Duplicate Triceps application name 'a1' is not allowed.\n");
	}

	// unsuccessfull find
	{
		string msg;
		try {
			a = App::find("a2");
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps application 'a2' is not found.\n");
	}

	// drop of an unknown app
	App::drop(a2);

	// drop of an old app with the same name has no effect
	Autoref<App> aa2 = App::make("a2"); // new one
	App::getList(amap);
	UT_IS(amap.size(), 2);
	App::drop(a2); // drop the old one
	App::getList(amap);
	UT_IS(amap.size(), 2);
	a = App::find("a2");
	UT_IS(a, aa2);

	// clean-up, since the apps catalog is global
	App::drop(a1);
	App::drop(aa2);

	restore_uncatchable();
}

// Test that a newly created app with no threads is considered ready and dead.
UTESTCASE empty_is_ready(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(a1->isDead());
	AppGuts::gutsWaitReady(a1);
	a1->waitDead();

	a1->waitNeedHarvest();
	UT_ASSERT(a1->harvest());

	restore_uncatchable();
}
