//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the App building.

#include <assert.h>
#include <utest/Utest.h>
#include <app/App.h>
#include <app/TrieadOwner.h>
#include <app/BasicPthread.h>

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
	// Busy-wait until the number of sleepers waiting for a
	// thread reaches the count.
	// @param tname - thread name for sleepers
	// @param n - the expected count of sleepers
	static void gutsWaitTrieadSleepers(App *a, const string &tname, int n)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		int nsl;
		do {
			sched_yield();
			pw::lockmutex lm(ag->mutex_);
			TrieadUpdMap::iterator it = ag->threads_.find(tname);
			assert(it != ag->threads_.end());
			nsl = it->second->_countSleepersL();
		} while(nsl != n);
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

class TestPthreadEmpty : public BasicPthread
{
public:
	TestPthreadEmpty(const string &name):
		BasicPthread(name),
		joined_(false)
	{ }

	virtual void execute(TrieadOwner *to)
	{
		to->markDead();
	}

	virtual void join()
	{
		BasicPthread::join();
		joined_ = true;
	}

	bool joined_;
};

// The minimal construction, starting and joining of BasicPthread.
UTESTCASE basic_pthread_join(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");

	Autoref<TestPthreadEmpty> pt1 = new TestPthreadEmpty("t1");
	pt1->start(a1);
	
	// clean-up, since the apps catalog is global
	a1->harvester();

	UT_ASSERT(pt1->joined_);

	restore_uncatchable();
}

class TestPthreadWait : public BasicPthread
{
public:
	TestPthreadWait(const string &name, const string &wname):
		BasicPthread(name),
		wname_(wname),
		result_(NULL)
	{ }

	virtual void execute(TrieadOwner *to)
	{
		result_ = to->findTriead(wname_).get();
		to->markDead();
	}

	string wname_;
	Triead *result_;
};

// thread finding by name, successful case
UTESTCASE find_triead_success(Utest *utest)
{
	make_catchable();
	
	Autoref<App> a1 = App::make("a1");
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");

	Triead *t;

	// Finding itself doesn't require the thread being constructed.
	t = ow1->findTriead("t1").get();
	UT_IS(t, ow1->get());

	Autoref<TestPthreadWait> pt2 = new TestPthreadWait("t2", "t1");
	pt2->start(a1);
	Autoref<TestPthreadWait> pt3 = new TestPthreadWait("t3", "t1");
	pt3->start(a1);

	// wait until t2 and t3 actually wait for t1
	AppGuts::gutsWaitTrieadSleepers(a1, "t1", 2);

	// marking t1 as constructed must wake up the sleepers
	ow1->markConstructed();
	AppGuts::gutsWaitTrieadSleepers(a1, "t1", 0);

	// now repeat the same with an only declared thread
	a1->declareTriead("t4");

	Autoref<TestPthreadWait> pt5 = new TestPthreadWait("t5", "t4");
	pt5->start(a1);
	Autoref<TestPthreadWait> pt6 = new TestPthreadWait("t6", "t4");
	pt6->start(a1);

	// wait until t5 and t6 actually wait for t4
	AppGuts::gutsWaitTrieadSleepers(a1, "t4", 2);

	// marking t4 as constructed must wake up the sleepers
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t4");
	ow4->markConstructed();
	AppGuts::gutsWaitTrieadSleepers(a1, "t4", 0);

	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow4->markDead();
	a1->harvester();

	UT_IS(pt2->result_, ow1->get());
	UT_IS(pt3->result_, ow1->get());

	restore_uncatchable();
}

// the abort of a thread
UTESTCASE basic_abort(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");

	// successful creation
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	UT_ASSERT(!AppGuts::gutsIsReady(a1));
	UT_ASSERT(!a1->isAborted());
	UT_ASSERT(!a1->isDead());

	Autoref<TestPthreadWait> pt2 = new TestPthreadWait("t2", "t1");
	pt2->start(a1);
	// wait until t2 actually waits for t1
	AppGuts::gutsWaitTrieadSleepers(a1, "t1", 1);

	// now abort! this will wake up the background thread too
	// (and throw an exception in it, which will be caught and
	// converted to another abort, which will be ignored)
	ow1->abort("test error");
	UT_ASSERT(AppGuts::gutsIsReady(a1));
	UT_ASSERT(a1->isAborted());
	// Can't check isDead() because of a race with t2.

	UT_IS(a1->getAbortedBy(), "t1");
	UT_IS(a1->getAbortedMsg(), "test error");

	// creating another thread doesn't reset the abort or readiness
	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t4");
	UT_ASSERT(AppGuts::gutsIsReady(a1));
	UT_ASSERT(a1->isAborted());
	UT_ASSERT(!a1->isDead()); // but now it's definitely not dead

	ow4->markReady();

	// a wait for any thread after abort throws an immediate exception,
	// even if the target thread is ready or even the same thread
	{
		string msg;
		try {
			ow3->findTriead("t4"); // t4 is ready and not aborted itself
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "App 'a1' has been aborted by thread 't1': test error\n");
	}
	{
		string msg;
		try {
			ow3->findTriead("t3"); // t4 is not aborted itself
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "App 'a1' has been aborted by thread 't1': test error\n");
	}

	// one more abort gets ignored
	ow3->abort("another msg");
	UT_IS(a1->getAbortedBy(), "t1");
	UT_IS(a1->getAbortedMsg(), "test error");

	// clean-up, since the apps catalog is global
	ow4->markDead();
	a1->harvester();

	restore_uncatchable();
}

UTESTCASE timeout_find(Utest *utest)
{
	make_catchable();

	// successfully change the time as relative seconds
	{
		Autoref<App> a1 = App::make("a1");

		a1->setTimeout(0); // for immediate failure

		Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
		Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
		a1->declareTriead("t3");

		// check the timeout for construction
		{
			string msg;
			try {
				ow1->findTriead("t2");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "Thread 't2' in application 'a1' did not initialize within the deadline.\n");
		}

		// also check the timeout for the readiness wait
		{
			string msg;
			try {
				ow1->readyReady();
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, 
				"Application 'a1' did not initialize within the deadline.\n"
				"The lagging threads are:\n"
				"  t2: not constructed\n"
				"  t3: not defined\n");
		}

		// still have to mark them dead to harvest
		Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
		ow1->markDead();
		ow2->markDead();
		ow3->markDead();
		a1->harvester();
	}

	// successfully change the time as absolute point
	{
		Autoref<App> a1 = App::make("a1");

		timespec tm;
		clock_gettime(CLOCK_REALTIME, &tm);
		a1->setDeadline(tm); // for immediate failure

		Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
		Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
		a1->declareTriead("t3");

		// check the timeout for construction of a declared thread
		{
			string msg;
			try {
				ow1->findTriead("t3");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "Thread 't3' in application 'a1' did not initialize within the deadline.\n");
		}

		// still have to mark them dead to harvest
		Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
		ow1->markDead();
		ow2->markDead();
		ow3->markDead();
		a1->harvester();
	}

	// can't change after the first thread was created
	{
		Autoref<App> a1 = App::make("a1");
		Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");

		{
			string msg;
			try {
				a1->setTimeout(0);
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "Triceps application 'a1' deadline can not be changed after the thread creation.\n");
		}
		{
			string msg;
			try {
				timespec tm;
				clock_gettime(CLOCK_REALTIME, &tm);
				a1->setDeadline(tm);
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "Triceps application 'a1' deadline can not be changed after the thread creation.\n");
		}

		ow1->markDead();
		a1->harvester();
	}

	restore_uncatchable();
}
