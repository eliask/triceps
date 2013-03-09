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

// do the basics: construct and start the threads, then request them to die
UTESTCASE create_die(Utest *utest)
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

	// start with a writer
	// Autoref<Facet> fa1a = 
	ow1->makeNexusWriter("nxa")
		->addLabel("one", rt1)
		->complete()
	;

	ow1->markConstructed();
	UT_ASSERT(ow1->get()->isInputOnly());
	ow1->markReady(); // ---

	// Autoref<Facet> fa2b = 
	ow2->makeNexusWriter("nxb")
		->addLabel("one", rt1)
		->complete()
	;
	// Autoref<Facet> fa2c = 
	ow2->makeNexusReader("nxc")
		->addLabel("one", rt1)
		->setReverse()
		->complete()
	;

	ow2->markReady(); // ---
	UT_ASSERT(!ow2->get()->isInputOnly());

	// Autoref<Facet> fa3b = 
	ow3->importReader("t2", "nxb", "");
	// Autoref<Facet> fa3c = 
	ow3->importWriter("t2", "nxc", "");

	ow3->markReady(); // ---
	UT_ASSERT(!ow3->get()->isInputOnly());

	// Autoref<Facet> fa4b = 
	ow4->importReader("t2", "nxb", "");

	ow4->markReady(); // ---
	UT_ASSERT(!ow4->get()->isInputOnly());

	// ----------------------------------------------------------------------

	ow1->readyReady();

	// ----------------------------------------------------------------------

	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow2->markDead();
	ow3->markDead();
	ow4->markDead();
	a1->harvester();

	restore_uncatchable();
}
