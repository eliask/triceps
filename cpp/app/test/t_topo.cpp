//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the App topology checking.

#include <utest/Utest.h>
#include <type/AllTypes.h>
#include "AppTest.h"

// construction of a graph
UTESTCASE mkgraph(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");

	// these threads and nexuses will be just used as graph fodder,
	// nothing more;
	// the connections don't matter because the graphs will be connected manually
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	Triead *t1 = ow1->get();
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
	Triead *t2 = ow2->get();

	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	Nexus *nx1 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx1")->addLabel("one", rt1)))->nexus();
	Nexus *nx2 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx2")->addLabel("one", rt1)))->nexus();
	
	// now build the graph
	{
		AppGuts::Graph g;
		AppGuts::NxTr *node;

		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		UT_IS(tnode1->tr_, t1);
		UT_IS(tnode1->nx_, NULL);
		UT_IS(tnode1->ninc_, 0);
		UT_ASSERT(tnode1->links_.empty());

		node = g.addTriead(t1); // following additions return the same node
		UT_IS(node, tnode1);

		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		UT_ASSERT(tnode2 != tnode1);

		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		UT_IS(nnode1->tr_, NULL);
		UT_IS(nnode1->nx_, nx1);
		UT_IS(nnode1->ninc_, 0);
		UT_ASSERT(nnode1->links_.empty());

		node = g.addNexus(nx1); // following additions return the same node
		UT_IS(node, nnode1);

		AppGuts::NxTr *nnode2 = g.addNexus(nx2);
		UT_ASSERT(nnode2 != nnode1);

		// this really should not be mixed in the same graph
		// but it's fine for a test
		AppGuts::NxTr *cnode1 = g.addCopy(tnode1);
		UT_IS(cnode1->tr_, t1);
		UT_IS(cnode1->nx_, NULL);
		UT_IS(cnode1->ninc_, 0);
		UT_ASSERT(cnode1->links_.empty());

		node = g.addCopy(tnode1); // following additions return the same node
		UT_IS(node, cnode1);

		AppGuts::NxTr *cnode2 = g.addCopy(nnode2);
		UT_IS(cnode2->tr_, NULL);
		UT_IS(cnode2->nx_, nx2);
		UT_ASSERT(cnode2 != cnode1);

		// printing
		UT_IS(tnode1->print(), "thread 't1'");
		UT_IS(nnode1->print(), "nexus 't1/nx1'");

		// connect the nodes
		tnode1->addLink(nnode1);
		UT_IS(tnode1->links_.size(), 1);
		UT_IS(tnode1->links_.back(), nnode1);
		UT_IS(nnode1->ninc_, 1);

		tnode1->addLink(nnode2);
		UT_IS(tnode1->links_.size(), 2);
		UT_IS(tnode1->links_.back(), nnode2);
		UT_IS(nnode1->ninc_, 1);

		tnode2->addLink(nnode1);
		UT_IS(tnode2->links_.size(), 1);
		UT_IS(tnode2->links_.back(), nnode1);
		UT_IS(nnode1->ninc_, 2);
	}

	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow2->markDead();
	a1->harvester(false);

	restore_uncatchable();
}
