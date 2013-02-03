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
class AppGuts : public App
{
public:
	static bool gutsIsReady(App *a)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		return ag->isReady();
	}
	static void gutsWaitReady(App *a)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		ag->waitReady();
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
	Autoref<App> a1 = App::make("a1");
	UT_ASSERT(AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(a1->isDead());
	AppGuts::gutsWaitReady(a1);
	a1->waitDead();

	a1->waitNeedHarvest();
	UT_ASSERT(a1->harvestOnce());

	// clean-up, since the apps catalog is global
	a1->harvester();
}

// Basic Triead creation, no actual OS-level threads yet.
UTESTCASE basic_trieads(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");

	// successful creation
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	// failed creation
	{
		string msg;
		try {
			Autoref<TrieadOwner> ow = a1->makeTriead("");
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Empty thread name is not allowed, in application 'a1'.\n");
	}
	{
		string msg;
		try {
			Autoref<TrieadOwner> ow = a1->makeTriead("t1");
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Duplicate thread name 't1' is not allowed, in application 'a1'.\n");
	}

	// TrieadOwner/Triead basic getters
	Autoref<Triead> t1 = ow1->get();
	UT_IS(t1->getName(), "t1");
	UT_ASSERT(!t1->isConstructed());
	UT_ASSERT(!t1->isReady());
	UT_ASSERT(!t1->isDead());

	UT_IS(ow1->unit()->getName(), "t1");
	UT_IS(ow1->app(), a1);

	// signal thread progression, one by one
	ow1->markConstructed();
	UT_ASSERT(t1->isConstructed());
	UT_ASSERT(!t1->isReady());
	UT_ASSERT(!t1->isDead());
	ow1->markReady();
	UT_ASSERT(t1->isConstructed());
	UT_ASSERT(t1->isReady());
	UT_ASSERT(!t1->isDead());
	ow1->markDead();
	UT_ASSERT(t1->isConstructed());
	UT_ASSERT(t1->isReady());
	UT_ASSERT(t1->isDead());

	// signal thread ready, implying constructed
	ow2->markReady();
	UT_ASSERT(ow2->get()->isConstructed());
	UT_ASSERT(ow2->get()->isReady());
	UT_ASSERT(!ow2->get()->isDead());

	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	// signal thread dead, implying constructed and ready
	ow3->markDead();
	UT_ASSERT(ow3->get()->isConstructed());
	UT_ASSERT(ow3->get()->isReady());
	UT_ASSERT(ow3->get()->isDead());

	UT_ASSERT(AppGuts::gutsIsReady(a1)); // all threads are ready now
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	// signal the last thread dead
	ow2->markDead();
	UT_ASSERT(ow2->get()->isConstructed());
	UT_ASSERT(ow2->get()->isReady());
	UT_ASSERT(ow2->get()->isDead());

	UT_ASSERT(AppGuts::gutsIsReady(a1)); // all threads are ready now
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(a1->isDead()); // all threads are dead now

	// repeated declaration of an existing thread is OK
	a1->declareTriead("t1");
	// nothing changes in readiness
	UT_ASSERT(AppGuts::gutsIsReady(a1)); // all threads are ready now
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(a1->isDead()); // all threads are dead now

	// declare one more thread
	a1->declareTriead("t4");
	// now have the unready and alive threads
	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	a1->declareTriead("t4"); // repeated declaration is OK

	// failed declare
	{
		string msg;
		try {
			a1->declareTriead("");
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Empty thread name is not allowed, in application 'a1'.\n");
	}

	// make the declared thread
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t4");
	// now have the unready and alive threads
	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	// mark the last thread dead
	ow4->markDead();
	UT_ASSERT(AppGuts::gutsIsReady(a1)); // all threads are ready now
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(a1->isDead()); // all threads are dead now

	// clean-up, since the apps catalog is global
	a1->harvester();

	restore_uncatchable();
}

// the abort of a thread
#if 0
UTESTCASE basic_abort(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");

	// successful creation
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

XXXXXXXXXX
	restore_uncatchable();
}
#endif
