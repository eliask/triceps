//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the App running.

#include <assert.h>
#include <utest/Utest.h>
#include <type/AllTypes.h>
#include <app/AutoDrain.h>
#include "AppTest.h"

// Call the nextXtray() recursive to test the exception.
class NextXtLabel: public Label
{
public:
	NextXtLabel(Unit *unit, Onceref<RowType> rtype, const string &name,
			TrieadOwner *to) :
		Label(unit, rtype, name),
		to_(to)
	{ }

	virtual void execute(Rowop *arg) const
	{ 
		to_->nextXtray();
	}

	TrieadOwner *to_;
};

// do the basics: construct and start the threads, then request them to die
UTESTCASE create_basics_die(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");
	a1->setTimeout(0); // will replace all waits with an Exception
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1"); // will be input-only
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2"); // t2 and t3 will form a loop
	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t4"); // will be output-only

	// prepare fragments
	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	FdataVec dv;
	mkfdata(dv);
	Rowref r1(rt1,  rt1->makeRow(dv));

	// start with a writer
	Autoref<Facet> fa1a = ow1->makeNexusWriter("nxa")
		->addLabel("one", rt1)
		->complete()
	;

	// a non-exported facet, to try the calls on it
	Autoref<Facet> fa1z = ow1->makeNexusNoImport("nxz")
		->addLabel("one", rt1)
		->complete()
	;

	ow1->markReady(); // ---
	UT_ASSERT(ow1->get()->isInputOnly());

	Autoref<Facet> fa2a = ow2->importReader("t1", "nxa", "");

	Autoref<Facet> fa2b = ow2->makeNexusWriter("nxb")
		->addLabel("one", rt1)
		->complete()
	;
	Autoref<Facet> fa2c = ow2->makeNexusReader("nxc")
		->addLabel("one", rt1)
		->setReverse()
		->complete()
	;

	// connect through from readers to writer
	fa2a->getFnReturn()->getLabel("one")->chain(
		fa2b->getFnReturn()->getLabel("one"));
	fa2c->getFnReturn()->getLabel("one")->chain(
		fa2b->getFnReturn()->getLabel("one"));

	ow2->markReady(); // ---
	UT_ASSERT(!ow2->get()->isInputOnly());

	Autoref<Facet> fa3b = ow3->importReader("t2", "nxb", "");
	Autoref<Facet> fa3c = ow3->importWriter("t2", "nxc", "");

	fa3b->getFnReturn()->getLabel("one")->chain(
		fa3c->getFnReturn()->getLabel("one"));

	ow3->markReady(); // ---
	UT_ASSERT(!ow3->get()->isInputOnly());

	Autoref<Facet> fa4b = ow4->importReader("t2", "nxb", "");

	// add a label for a test for recursive nextXlabel()
	Autoref<Label> recl = new NextXtLabel(ow4->unit(), rt1, "recl", ow4);
	fa4b->getFnReturn()->getLabel("one")->chain(recl);

	ow4->markReady(); // ---
	UT_ASSERT(!ow4->get()->isInputOnly());

	ow1->readyReady();
	ow2->readyReady();
	ow3->readyReady();
	ow4->readyReady();

	// ----------------------------------------------------------------------
	
	// pass around a little data
	ow1->unit()->call(new Rowop(fa1a->getFnReturn()->getLabel("one"), 
		Rowop::OP_INSERT, r1));
	UT_ASSERT(ow1->flushWriters());

	// should be now in fa2a queue
	Autoref<ReaderQueue> rq2a = FacetGuts::readerQueue(fa2a);
	UT_IS(ReaderQueueGuts::writeq(rq2a).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq2a).size(), 0);

	// process through t2
	UT_ASSERT(ow2->nextXtray());
 
	// should be now in fa3b and fa4b queues
	Autoref<ReaderQueue> rq3b = FacetGuts::readerQueue(fa3b);
	UT_IS(ReaderQueueGuts::writeq(rq3b).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq3b).size(), 0);

	Autoref<ReaderQueue> rq4b = FacetGuts::readerQueue(fa4b);
	UT_IS(ReaderQueueGuts::writeq(rq4b).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq4b).size(), 0);

	// process through t3
	UT_ASSERT(ow3->nextXtray());
 
	// should be now in fa2c queue
	Autoref<ReaderQueue> rq2c = FacetGuts::readerQueue(fa2c);
	UT_IS(ReaderQueueGuts::writeq(rq2c).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq2c).size(), 0);

	// run t4 to test the recursive call
	{
		string msg;
		try {
			ow4->nextXtray();
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, 
			"Can not call the queue processing in thread 't4' recursively.\n"
			"Called through the label 'recl'.\n"
			"Called chained from the label 'nxb.one'.\n");
	}

	// one more round to t4, to make sure that it doesn't get stuck
	ow2->unit()->call(new Rowop(fa2b->getFnReturn()->getLabel("one"), 
		Rowop::OP_INSERT, r1));
	UT_ASSERT(ow2->flushWriters());
	UT_IS(ReaderQueueGuts::writeq(rq4b).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq4b).size(), 0);
	{
		string msg;
		try {
			ow4->nextXtray();
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, 
			"Can not call the queue processing in thread 't4' recursively.\n"
			"Called through the label 'recl'.\n"
			"Called chained from the label 'nxb.one'.\n");
	}

	// do a no-wait processing attempt
	UT_ASSERT(!ow4->nextXtray(false));
	UT_ASSERT(ow3->nextXtray(false)); // ow3 has data in the queue
	UT_ASSERT(!ow3->nextXtray(false));

	// ----------------------------------------------------------------------

	// gradually shut down

	// make sure that there is some data in the write queue before shutdown
	// to test that it will be ignored
	UT_IS(ReaderQueueGuts::writeq(rq2c).size(), 2);
	ow2->requestMyselfDead();

	// writing to the requested-dead ow2 is not queuing data any more
	UT_IS(ReaderQueueGuts::writeq(rq2a).size(), 0);
	ow1->unit()->call(new Rowop(fa1a->getFnReturn()->getLabel("one"), 
		Rowop::OP_INSERT, r1));
	UT_ASSERT(ow1->flushWriters());
	UT_IS(ReaderQueueGuts::writeq(rq2a).size(), 0);

	// the attempts to read will fail after request dead
	UT_ASSERT(!ow2->nextXtray());

	a1->requestDrain();
	UT_IS(AppGuts::getDrain(a1)->left_, 3);

	ow2->markDead();
	UT_ASSERT(rq2c->isDead());
	UT_IS(ReaderQueueGuts::writeq(rq2c).size(), 0); // dead clears the queue

	TrieadGuts::requestDead(ow3->get());
	TrieadGuts::requestDead(ow4->get());

	ow3->markDead();
	ow4->markDead();
	
	// now with only an input-only thread alive, the drain would succeed
	
	UT_IS(AppGuts::getDrain(a1)->left_, 0);

	a1->waitDrain();
	a1->undrain();

	// now drain and request t1 dead when drained

	a1->drain();
	UT_ASSERT(ow1->isRqDrain());
	TrieadGuts::requestDead(ow1->get());
	UT_ASSERT(ow1->isRqDead());
	a1->undrain();

	UT_ASSERT(!ow1->flushWriters()); // no more writing

	ow1->markDead();

	// ----------------------------------------------------------------------

	// clean-up, since the apps catalog is global
	a1->harvester();

	restore_uncatchable();
}

class LoopPthread : public BasicPthread
{
public:
	LoopPthread(const string &name):
		BasicPthread(name),
		ev_(true) // by default it just runs
	{ 
	}

	// overrides BasicPthread::start
	virtual void execute(TrieadOwner *to)
	{
		// like MainLoop() but increase the counter after each Xtray
		while (to->nextXtray()) {
			cnt_.inc();
			ev_.wait();
		}
		to->requestMyselfDead(); // just to see that it doesn't break anything
		to->markDead();
	}

	AtomicInt cnt_; 
	pw::event2 ev_;
};

// A label that forwards data unless it's told to stop
class ForwardLabel: public Label
{
public:
	ForwardLabel(Unit *unit, Onceref<RowType> rtype, const string &name,
			Label *dest) :
		Label(unit, rtype, name),
		dest_(dest),
		forward_(1)
	{ }

	virtual void execute(Rowop *arg) const
	{ 
		if (forward_.get()) {
			unit_->call(dest_->adopt(arg));
		}
	}

	void enable()
	{
		forward_.set(1);
	}

	void disable()
	{
		forward_.set(0);
	}

	Autoref<Label> dest_; // the destination label
	AtomicInt forward_; // flag: forward the data
};

// a set of threads that will be used for multiple tests
class TestThreads1
{
public:
	TestThreads1(Utest *utest)
	{
		a1 = App::make("a1");
		a1->setTimeout(0); // will replace all waits with an Exception
		ow1 = a1->makeTriead("t1"); // will be input-only
		ow2 = a1->makeTriead("t2"); // t2 and t3 will form a loop
		ow3 = a1->makeTriead("t3");

		// prepare elements
		mkfields(fld);
		rt1 = new CompactRowType(fld);

		mkfdata(dv);
		r1.assign(rt1,  rt1->makeRow(dv));

		// start with a writer
		fa1a = ow1->makeNexusWriter("nxa")
			->addLabel("one", rt1)
			->complete()
		;

		// a non-exported facet, to try the calls on it
		fa1z = ow1->makeNexusNoImport("nxz")
			->addLabel("one", rt1)
			->complete()
		;

		// check that isDrained() works even when the app is not ready
		UT_ASSERT(!a1->isDrained());
		UT_ASSERT(!ow1->isDrained());

		ow1->markReady(); // ---
		UT_ASSERT(ow1->get()->isInputOnly());

		fa2a = ow2->importReader("t1", "nxa", "");

		fa2b = ow2->makeNexusWriter("nxb")
			->addLabel("one", rt1)
			->complete()
		;
		fa2c = ow2->makeNexusReader("nxc")
			->addLabel("one", rt1)
			->setReverse()
			->complete()
		;

		// connect through from readers to writer
		fwd2a = new ForwardLabel(ow2->unit(), rt1, "fwd2a", 
			fa2b->getFnReturn()->getLabel("one"));
		fa2a->getFnReturn()->getLabel("one")->chain(fwd2a);

		fwd2c = new ForwardLabel(ow2->unit(), rt1, "fwd2c", 
			fa2b->getFnReturn()->getLabel("one"));
		fa2c->getFnReturn()->getLabel("one")->chain(fwd2c);

		ow2->markReady(); // ---
		UT_ASSERT(!ow2->get()->isInputOnly());

		fa3b = ow3->importReader("t2", "nxb", "");
		fa3c = ow3->importWriter("t2", "nxc", "");

		fwd3b = new ForwardLabel(ow3->unit(), rt1, "fwd3b", 
			fa3c->getFnReturn()->getLabel("one"));
		fa3b->getFnReturn()->getLabel("one")->chain(fwd3b);

		ow3->markReady(); // ---
		UT_ASSERT(!ow3->get()->isInputOnly());
	}

	Autoref<App> a1;
	Autoref<TrieadOwner> ow1; // will be input-only
	Autoref<TrieadOwner> ow2; // t2 and t3 will form a loop
	Autoref<TrieadOwner> ow3;

	RowType::FieldVec fld;
	Autoref<RowType> rt1;

	FdataVec dv;
	Rowref r1;

	Autoref<Facet> fa1a;
	Autoref<Facet> fa1z;
	Autoref<Facet> fa2a;
	Autoref<Facet> fa2b;
	Autoref<Facet> fa2c;
	Autoref<Facet> fa3b;
	Autoref<Facet> fa3c;

	Autoref<ForwardLabel> fwd2a;
	Autoref<ForwardLabel> fwd2c;
	Autoref<ForwardLabel> fwd3b;

private:
	TestThreads1();
};

// check that the shutdown stops a loop
UTESTCASE shutdown_loop(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<LoopPthread> pt3 = new LoopPthread("t3");
	pt3->start(tt.ow3);

	// initiate an endless loop between t2 and t3
	tt.ow1->unit()->call(new Rowop(tt.fa1a->getFnReturn()->getLabel("one"), 
		Rowop::OP_INSERT, tt.r1));
	UT_ASSERT(tt.ow1->flushWriters());

	// let it run a little before shutdown
	while (((unsigned)pt2->cnt_.get()) < 100)
		sched_yield();

	// ----------------------------------------------------------------------

	tt.ow1->markDead(); // ow1 is controlled manually
	tt.a1->shutdown(); // request all the threads to die

	// create one more thread after shutdown
	Autoref<TrieadOwner> ow4 = tt.a1->makeTriead("t4");
	ow4->readyReady();
	UT_ASSERT(ow4->isRqDead()); // gets requested to die right away
	ow4->markDead();

	tt.a1->harvester();

	restore_uncatchable();
}

// check that the drain doesn't succeed until the running loop stops
UTESTCASE drain_loop(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<LoopPthread> pt3 = new LoopPthread("t3");
	pt3->start(tt.ow3);

	// initiate an endless loop between t2 and t3
	tt.ow1->unit()->call(new Rowop(tt.fa1a->getFnReturn()->getLabel("one"), 
		Rowop::OP_INSERT, tt.r1));
	UT_ASSERT(tt.ow1->flushWriters());

	// request a drain
	UT_ASSERT(!tt.a1->isDrained());
	tt.ow1->requestDrainShared(); // for a difference, go through TrieadOwner
	UT_ASSERT(!tt.a1->isDrained());

	// let the loop run a little to see that it's not interrupted
	unsigned start = (unsigned)pt2->cnt_.get();
	while (((unsigned)pt2->cnt_.get() - start) < 100)
		sched_yield();
	UT_ASSERT(!tt.a1->isDrained()); // and sure enough, still not drained

	tt.fwd2c->disable(); // break the loop
	tt.ow1->waitDrain(); // should succeed now

	// ----------------------------------------------------------------------

	tt.ow1->markDead(); // ow1 is controlled manually
	tt.a1->shutdown(); // request all the threads to die, and draining doesn't stop it

	tt.ow1->undrain(); // doesn't matter by now but just test the call

	tt.a1->harvester();

	restore_uncatchable();
}

// mark the App as drained, then add threads;
// also do the drains with indefined (but declared) threads
UTESTCASE drain_unready(Utest *utest)
{
	make_catchable();

	Autoref<ForwardLabel> fwd2a;
	Autoref<ForwardLabel> fwd2c;
	Autoref<ForwardLabel> fwd3b;

	Autoref<App> a1 = App::make("a1");
	a1->setTimeout(0); // will replace all waits with an Exception

	a1->declareTriead("t1");
	a1->declareTriead("t2");

	a1->requestDrain(); // must not crash
	UT_ASSERT(a1->isDrained()); // since only the ready threads are included

	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1"); // will be input-only
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2"); // t2 and t3 will form a loop
	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");

	// prepare fragments
	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	FdataVec dv;
	mkfdata(dv);
	Rowref r1(rt1,  rt1->makeRow(dv));

	// start with a writer
	Autoref<Facet> fa1a = ow1->makeNexusWriter("nxa")
		->addLabel("one", rt1)
		->complete()
	;

	// a non-exported facet, to try the calls on it
	Autoref<Facet> fa1z = ow1->makeNexusNoImport("nxz")
		->addLabel("one", rt1)
		->complete()
	;

	ow1->markReady(); // ---
	UT_ASSERT(ow1->get()->isInputOnly());

	Autoref<Facet> fa2a = ow2->importReader("t1", "nxa", "");

	Autoref<Facet> fa2b = ow2->makeNexusWriter("nxb")
		->addLabel("one", rt1)
		->complete()
	;
	Autoref<Facet> fa2c = ow2->makeNexusReader("nxc")
		->addLabel("one", rt1)
		->setReverse()
		->complete()
	;

	// connect through from readers to writer
	fwd2a = new ForwardLabel(ow2->unit(), rt1, "fwd2a", 
		fa2b->getFnReturn()->getLabel("one"));
	fa2a->getFnReturn()->getLabel("one")->chain(fwd2a);

	fwd2c = new ForwardLabel(ow2->unit(), rt1, "fwd2c", 
		fa2b->getFnReturn()->getLabel("one"));
	fa2c->getFnReturn()->getLabel("one")->chain(fwd2c);

	ow2->markReady(); // ---
	UT_ASSERT(!ow2->get()->isInputOnly());

	Autoref<Facet> fa3b = ow3->importReader("t2", "nxb", "");
	Autoref<Facet> fa3c = ow3->importWriter("t2", "nxc", "");

	fwd3b = new ForwardLabel(ow3->unit(), rt1, "fwd3b", 
		fa3c->getFnReturn()->getLabel("one"));
	fa3b->getFnReturn()->getLabel("one")->chain(fwd3b);

	ow3->markReady(); // ---
	UT_ASSERT(!ow3->get()->isInputOnly());

	ow1->readyReady();
	ow2->readyReady();
	ow3->readyReady();

	// ----------------------------------------------------------------------

	UT_ASSERT(!a1->isDrained());
	
	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(ow2);
	Autoref<LoopPthread> pt3 = new LoopPthread("t3");
	pt3->start(ow3);

	a1->waitDrain(); // should succeed now

	// declare one more thread, which would be still drained
	a1->declareTriead("t4");
	UT_ASSERT(a1->isDrained());

	a1->undrain(); // must not crash with an undefined thread

	// ----------------------------------------------------------------------

	a1->requestDrain();
	UT_ASSERT(a1->isDrained());

	Autoref<TrieadOwner> ow4 = a1->makeTriead("t4");
	UT_ASSERT(a1->isDrained());
	
	Autoref<TrieadOwner> ow5 = a1->makeTriead("t5");
	UT_ASSERT(a1->isDrained());
	
	// ow4 will be an input-only thread
	Autoref<Facet> fa4d = ow4->makeNexusWriter("nxd")
		->addLabel("one", rt1)
		->complete()
	;

	// ow5 will have a reader
	Autoref<Facet> fa5a = ow5->importReader("t1", "nxa", "");

	ow4->markReady();
	UT_ASSERT(a1->isDrained()); // still drained, since it's input-only
	ow5->markReady();
	UT_ASSERT(!a1->isDrained()); // undrained, since it's not in the reading loop

	ow4->readyReady();
	ow5->readyReady();

	Autoref<LoopPthread> pt5 = new LoopPthread("t5");
	pt5->start(ow5);

	a1->waitDrain(); // became drained by entering the main loop

	// ----------------------------------------------------------------------

	ow1->markDead(); // ow1 is controlled manually
	ow4->markDead(); // ow4 is controlled manually
	a1->shutdown(); // request all the threads to die, and draining doesn't stop it

	a1->harvester();

	restore_uncatchable();
}

// check that the drain feels OK when a fragment gets shut down
UTESTCASE drain_frag(Utest *utest)
{
	make_catchable();

	App::TrieadMap tm;
	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	Autoref<TrieadOwner> ow4 = tt.a1->makeTriead("t4", "frag1");
	Autoref<Facet> fa4b = ow4->importReader("t2", "nxb", "");
	Autoref<Facet> fa4c = ow4->importWriter("t2", "nxc", "");
	ow4->readyReady();

	Autoref<Nexus> nxb = fa4b->nexus();
	Autoref<Nexus> nxc = fa4c->nexus();

	UT_IS(NexusGuts::readers(nxb)->v().size(), 2);
	UT_IS(NexusGuts::writers(nxc)->size(), 2);
	
	// ----------------------------------------------------------------------

	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<LoopPthread> pt3 = new LoopPthread("t3");
	pt3->start(tt.ow3);
	Autoref<LoopPthread> pt4 = new LoopPthread("t4");
	pt4->start(ow4);

	// do a drain
	UT_ASSERT(!tt.a1->isDrained());
	tt.a1->drain();

	// shutdown the frag
	tt.a1->shutdownFragment("frag1");
	while(!ow4->get()->isDead()) // will make the thread exit
		sched_yield();

	sched_yield();
	sched_yield();
	sched_yield();

	// make sure that the thread is not disposed of yet
	tt.a1->getTrieads(tm);
	UT_IS(tm.size(), 4);

	// harvest the thread
	UT_ASSERT(!tt.a1->harvestOnce());
	tt.a1->getTrieads(tm);
	UT_IS(tm.size(), 3);

	// check that it got disconnected from the nexuses
	UT_IS(NexusGuts::readers(nxb)->v().size(), 1);
	UT_IS(NexusGuts::writers(nxc)->size(), 1);
	
	// ----------------------------------------------------------------------

	tt.ow1->markDead(); // ow1 is controlled manually
	tt.a1->shutdown(); // request all the threads to die, and draining doesn't stop it

	tt.a1->harvester();

	restore_uncatchable();
}

// check that the drain feels OK if a fragment was already drained
UTESTCASE drain_after_frag(Utest *utest)
{
	make_catchable();

	App::TrieadMap tm;
	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	Autoref<TrieadOwner> ow4 = tt.a1->makeTriead("t4", "frag1");
	ow4->importReader("t2", "nxb", "");
	ow4->importWriter("t2", "nxc", "");
	ow4->readyReady();
	
	// ----------------------------------------------------------------------

	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<LoopPthread> pt3 = new LoopPthread("t3");
	pt3->start(tt.ow3);
	Autoref<LoopPthread> pt4 = new LoopPthread("t4");
	pt4->start(ow4);

	// shutdown the frag
	tt.a1->shutdownFragment("frag1");
	while(!ow4->get()->isDead()) // will make the thread exit
		sched_yield();

	sched_yield();
	sched_yield();
	sched_yield();

	// make sure that the thread is not disposed of yet
	tt.a1->getTrieads(tm);
	UT_IS(tm.size(), 4);

	// do a drain
	UT_ASSERT(!tt.a1->isDrained());
	tt.a1->drain();

	// harvest the thread
	UT_ASSERT(!tt.a1->harvestOnce());
	tt.a1->getTrieads(tm);
	UT_IS(tm.size(), 3);

	// ----------------------------------------------------------------------

	tt.ow1->markDead(); // ow1 is controlled manually
	tt.a1->shutdown(); // request all the threads to die, and draining doesn't stop it

	tt.a1->harvester();

	restore_uncatchable();
}

// drain with exception of a thread
UTESTCASE drain_except(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<LoopPthread> pt3 = new LoopPthread("t3");
	pt3->start(tt.ow3);

	// request a drain
	UT_ASSERT(!tt.a1->isDrained());
	tt.ow1->requestDrainExclusive();
	tt.a1->waitDrain();

	// still can send from ow1 and initiate an endless loop between t2 and t3
	tt.ow1->unit()->call(new Rowop(tt.fa1a->getFnReturn()->getLabel("one"), 
		Rowop::OP_INSERT, tt.r1));
	UT_ASSERT(tt.ow1->flushWriters());
	UT_ASSERT(!tt.a1->isDrained()); // not drained any more

	// let the loop run a little to see that it's not interrupted
	unsigned start = (unsigned)pt2->cnt_.get();
	while (((unsigned)pt2->cnt_.get() - start) < 100)
		sched_yield();
	UT_ASSERT(!tt.a1->isDrained()); // and sure enough, still not drained

	tt.fwd2c->disable(); // break the loop
	tt.a1->waitDrain(); // should succeed now

	// ----------------------------------------------------------------------

	tt.ow1->markDead(); // ow1 is controlled manually
	tt.a1->shutdown(); // request all the threads to die, and draining doesn't stop it

	tt.a1->harvester();

	restore_uncatchable();
}

class DrainParallelT: public Mtarget, public pw::pwthread
{
public:
	// will write this xtray to this queue at this id
	DrainParallelT(App *app):
		app_(app),
		drained_(false)
	{ }

	virtual void *execute()
	{
		app_->drain();
		drained_ = true;
		app_->undrain();
		return NULL;
	}

	Autoref<App> app_;
	bool drained_;
};

class DrainExclusiveT: public Mtarget, public pw::pwthread
{
public:
	// will write this xtray to this queue at this id
	DrainExclusiveT(TrieadOwner *to):
		to_(to),
		drained_(false)
	{ }

	virtual void *execute()
	{
		AutoDrainExclusive adx(to_);
		drained_ = true;
		return NULL;
	}

	Autoref<TrieadOwner> to_;
	bool drained_;
};

// Multiple parallel drain requests
UTESTCASE drain_parallel(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	// the background to comply with draining
	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<LoopPthread> pt3 = new LoopPthread("t3");
	pt3->start(tt.ow3);

	// ----------------------------------------------------------------------

	// get a shared drain
	tt.a1->drain();
	Autoref<DrainExclusiveT> dt0 = new DrainExclusiveT(tt.ow1);
	{
		// do it recursevly a couple more times, with scoped varieties
		Autoref<AutoDrainShared> ad1 = new AutoDrainShared(tt.a1);
		AutoDrainShared ad2(tt.ow1, false);
		ad2.wait();

		// an exclusive drain will wait
		dt0->start();
		
		// the other shared drain will succeed
		Autoref<DrainParallelT> dt1 = new DrainParallelT(tt.a1);
		dt1->start();
		Autoref<DrainParallelT> dt2 = new DrainParallelT(tt.a1);
		dt2->start();

		dt1->join();
		dt2->join();

		UT_ASSERT(!dt0->drained_);
	}
	// check that the exclusive drain still waits
	UT_ASSERT(!dt0->drained_);
	tt.a1->undrain();

	dt0->join(); // now the exclusive drain succeeded

	// ----------------------------------------------------------------------

	Autoref<DrainExclusiveT> dt3 = new DrainExclusiveT(tt.ow1);
	Autoref<DrainParallelT> dt4 = new DrainParallelT(tt.a1);
	{
		// get an exclusive drain with a scope
		AutoDrainExclusive ad3(tt.ow1, false);
		ad3.wait();

		// an exclusive drain will wait
		dt3->start();
		
		// a shared drain will wait too
		dt4->start();

		sched_yield();
		sched_yield();
		sched_yield();
		sched_yield();
		sched_yield();
		sched_yield();
		sched_yield();
		sched_yield();

		UT_ASSERT(!dt3->drained_);
		UT_ASSERT(!dt4->drained_);
	}
	// undraining will leth them both through, one by one
	dt3->join();
	dt4->join();

	// ----------------------------------------------------------------------

	tt.ow1->markDead(); // ow1 is controlled manually
	tt.a1->shutdown(); // request all the threads to die, and draining doesn't stop it

	tt.a1->harvester();

	restore_uncatchable();
}

class MainLoopPthread : public BasicPthread
{
public:
	MainLoopPthread(const string &name):
		BasicPthread(name)
	{ 
	}

	// overrides BasicPthread::start
	virtual void execute(TrieadOwner *to)
	{
		to->mainLoop(); // test of mainLoop
	}
};

// a thread that sleeps on a file opeation, it makes a pipe
// from which attempts to read
class FdPthread : public BasicPthread
{
public:
	FdPthread(const string &name):
		BasicPthread(name),
		bytes_(0),
		loops_(0),
		raw_errno_(0),
		errno_(0),
		exit_(0)
	{ }

	// overrides BasicPthread::start
	virtual void execute(TrieadOwner *to)
	{
		assert(pipe(fd_) == 0);

		readyOpen_.signal();
		mayOpen_.wait();

		fi_->openFd(fd_[0]);
		fi_->openFd(fd_[1]);

		readyLoop_.signal();
		mayLoop_.signal();

		while (!exit_ && !to->isRqDead()) {
			++loops_;
			char bf[10];
			int len  = read(fd_[0], bf, sizeof(bf));
			if (len < 0) {
				raw_errno_ = errno;
				if (to->isRqDead())
					break; // interrupt
				errno_ = raw_errno_; // properly ignoring the error from interruption
			} else if (len == 0) {
				break; // EOF
			} else {
				bytes_ += len; // normal read
			}
		}

		fi_->closeFd(fd_[0]);
		fi_->closeFd(fd_[1]);

		readyClose_.signal();
		mayClose_.signal();

		close(fd_[0]);
		close(fd_[1]);
	}

	void mayAll() // enable to proceed without detailed synchronization
	{
		mayOpen_.signal();
		mayLoop_.signal();
		mayClose_.signal();
	}

	int fd_[2]; // read, write
	int bytes_; // number of bytes read
	int loops_; // number of loops done
	int raw_errno_; // as reported by the system call
	int errno_; // ignoring the errors from interruption
	int exit_; // can be used to exit the loop early
	pw::event2 readyOpen_, readyLoop_, readyClose_; // signals when ready to do the next step
	pw::event2 mayOpen_, mayLoop_, mayClose_; // waits until allowed to do the next step
};


// the interruption of file operations on shutdown, before files are reported open
UTESTCASE interrupt_fd_open(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	Autoref<FdPthread> pt1 = new FdPthread("t1");
	pt1->start(tt.ow1);
	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<MainLoopPthread> pt3 = new MainLoopPthread("t3");
	pt3->start(tt.ow3);

	// ----------------------------------------------------------------------

	// syncronize the interrupt at before open
	pt1->readyOpen_.wait();

	tt.a1->shutdown(); // request all the threads to die

	pt1->mayOpen_.signal();
	pt1->mayLoop_.signal();
	pt1->mayClose_.signal();

	// ----------------------------------------------------------------------

	tt.a1->harvester();

	UT_IS(pt1->loops_, 0);

	restore_uncatchable();
}

// the interruption of file operations on shutdown, while in the loop
UTESTCASE interrupt_fd_loop(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	Autoref<FdPthread> pt1 = new FdPthread("t1");
	pt1->start(tt.ow1);
	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<MainLoopPthread> pt3 = new MainLoopPthread("t3");
	pt3->start(tt.ow3);

	// ----------------------------------------------------------------------

	pt1->mayOpen_.signal();

	// syncronize the interrupt inside the loop
	pt1->readyLoop_.wait();
	pt1->mayLoop_.signal();

	// no way to tell reliably that the thread is sleeping, so do a guess
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	// sleep(1); // if want to be extra sure

	tt.a1->shutdown(); // request all the threads to die

	pt1->mayClose_.signal();

	// ----------------------------------------------------------------------

	tt.a1->harvester();

	UT_IS(pt1->loops_, 1);

	restore_uncatchable();
}

// the interruption of file operations on shutdown, before files are reported closed
UTESTCASE interrupt_fd_close(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	Autoref<FdPthread> pt1 = new FdPthread("t1");
	pt1->start(tt.ow1);
	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<MainLoopPthread> pt3 = new MainLoopPthread("t3");
	pt3->start(tt.ow3);

	// ----------------------------------------------------------------------

	// syncronize the interrupt at before close
	pt1->exit_ = 1;
	pt1->mayOpen_.signal();
	pt1->mayLoop_.signal();

	pt1->readyClose_.wait();

	tt.a1->shutdown(); // request all the threads to die

	pt1->mayClose_.signal();

	// ----------------------------------------------------------------------

	tt.a1->harvester();

	UT_IS(pt1->loops_, 0);

	restore_uncatchable();
}

// the abort shuts down the running threads
UTESTCASE shutdown_on_abort(Utest *utest)
{
	make_catchable();

	TestThreads1 tt(utest);

	tt.ow1->readyReady();
	tt.ow2->readyReady();
	tt.ow3->readyReady();

	// ----------------------------------------------------------------------

	Autoref<FdPthread> pt1 = new FdPthread("t1");
	pt1->start(tt.ow1);
	pt1->mayAll();

	Autoref<LoopPthread> pt2 = new LoopPthread("t2");
	pt2->start(tt.ow2);
	Autoref<MainLoopPthread> pt3 = new MainLoopPthread("t3");
	pt3->start(tt.ow3);

	// ----------------------------------------------------------------------

	// give the threads a little time...
	pt1->readyLoop_.wait();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();
	sched_yield();

	// create an abort by adding a thread that will induce an illegal loop
	Autoref<TrieadOwner> ow4 = tt.a1->makeTriead("t4");
	ow4->importWriter("t1", "nxa", "");
	ow4->importReader("t2", "nxb", "");
	{
		string msg;
		try {
			ow4->readyReady(); // will abort here
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, 
			"In application 'a1' detected an illegal direct loop:\n"
			"  thread 't2'\n"
			"  nexus 't2/nxb'\n"
			"  thread 't4'\n"
			"  nexus 't1/nxa'\n"
			"  thread 't2'\n"
		);
	}

	// ----------------------------------------------------------------------

	{
		string msg;
		try {
			tt.a1->harvester(); // throws after it's done
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg,
			"App 'a1' has been aborted by thread 't4': In application 'a1' detected an illegal direct loop:\n"
			"  thread 't2'\n"
			"  nexus 't2/nxb'\n"
			"  thread 't4'\n"
			"  nexus 't1/nxa'\n"
			"  thread 't2'\n"
		);
	}

	restore_uncatchable();
}

class WriteTransT: public Mtarget, public pw::pwthread
{
public:
	// will write this xtray to this queue at this id
	WriteTransT(TrieadOwner *to, Rowop *op, int count):
		to_(to),
		op_(op),
		count_(count),
		written_(0)
	{ }

	virtual void *execute()
	{
		for (written_ = 0; written_ < count_; written_++) {
			to_->unit()->call(op_);
			to_->flushWriters();
		}
		return NULL;
	}

	Autoref<TrieadOwner> to_;
	Autoref<Rowop> op_; // rowop to send in every transaction
	int count_; // number of transactions to write
	int written_; // number of transactiond written
};


// requesting a thread dead disconnects it from the nexuses, and wakes up
// any other threads trying to write there
UTESTCASE shutdown_disconnects(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");
	a1->setTimeout(0); // will replace all waits with an Exception
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");

	// prepare elements
	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	FdataVec dv;
	mkfdata(dv);
	Rowref r1(rt1,  dv);

	// low queue limit, to make sure that the writer gets stuck
	Autoref<Facet> fa1a = ow1->makeNexusWriter("nxa")
		->addLabel("one", rt1)
		->setQueueLimit(1)
		->complete()
	;
	ow1->markReady();

	Autoref<Facet> fa2a = ow2->importReader("t1", "nxa", "");
	Autoref<ReaderQueue> rq2a = FacetGuts::readerQueue(fa2a);
	UT_ASSERT(!rq2a.isNull());
	ow2->markReady();
	
	ow1->readyReady();
	ow2->readyReady();

	Autoref<WriteTransT> wt1 = new WriteTransT(ow1,
		new Rowop(fa1a->getFnReturn()->getLabel("one"), Rowop::OP_INSERT, r1), 
		100);

	wt1->start();

	// make sure that the write gets stuck on a full buffer
	ReaderQueueGuts::waitCondfullSleep(rq2a, 1);

	// now request the t2 dead
	TrieadGuts::requestDead(ow2->get());

	// the writer should wake up and continue to the end
	wt1->join();

	ow1->markDead();
	ow2->markDead();

	a1->harvester();

	restore_uncatchable();
}
