//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the App running.

#include <utest/Utest.h>
#include <type/AllTypes.h>
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
	ReaderQueue *rq2a = FacetGuts::readerQueue(fa2a);
	UT_IS(ReaderQueueGuts::writeq(rq2a).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq2a).size(), 0);

	// process through t2
	UT_ASSERT(ow2->nextXtray());
 
	// should be now in fa3b and fa4b queues
	ReaderQueue *rq3b = FacetGuts::readerQueue(fa3b);
	UT_IS(ReaderQueueGuts::writeq(rq3b).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq3b).size(), 0);

	ReaderQueue *rq4b = FacetGuts::readerQueue(fa4b);
	UT_IS(ReaderQueueGuts::writeq(rq4b).size(), 1);
	UT_IS(ReaderQueueGuts::readq(rq4b).size(), 0);

	// process through t3
	UT_ASSERT(ow3->nextXtray());
 
	// should be now in fa2c queue
	ReaderQueue *rq2c = FacetGuts::readerQueue(fa2c);
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
	TrieadGuts::requestDead(ow2->get());

	// the attempts to read will fail after request dead
	UT_ASSERT(!ow2->nextXtray());

	TrieadGuts::requestDead(ow3->get());
	TrieadGuts::requestDead(ow4->get());

	a1->requestDrain();
	UT_IS(AppGuts::getDrain(a1)->left_, 3);

	ow2->markDead();
	ow3->markDead();
	ow4->markDead();
	
	// now with only an input-only thread alive, the drain would succeed
	
	UT_IS(AppGuts::getDrain(a1)->left_, 0);

	a1->waitDrain();
	a1->undrain();

	// now drain and request t1 dead when drained

	a1->drain();
	TrieadGuts::requestDead(ow1->get());
	a1->undrain();

	UT_ASSERT(!ow1->flushWriters()); // no more writing

	ow1->markDead();

	// ----------------------------------------------------------------------

	// clean-up, since the apps catalog is global
	a1->harvester();

	restore_uncatchable();
}
