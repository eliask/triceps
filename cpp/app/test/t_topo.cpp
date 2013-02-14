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

UTESTCASE reduce(Utest *utest)
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
	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
	Triead *t3 = ow3->get();
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t4");
	Triead *t4 = ow4->get();

	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	Nexus *nx1 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx1")->addLabel("one", rt1)))->nexus();
	Nexus *nx2 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx2")->addLabel("one", rt1)))->nexus();
	Nexus *nx3 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx3")->addLabel("one", rt1)))->nexus();
	Nexus *nx4 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx4")->addLabel("one", rt1)))->nexus();

	// now build the graphs and reduce them
	
	// a disconnected graph
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		AppGuts::reduceGraphL(g); // a no-op here

		UT_IS(tnode1->ninc_, 0);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(nnode1->ninc_, 0);
		UT_IS(nnode2->ninc_, 0);
	}
	// a straight line
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		nnode1->addLink(tnode2);
		tnode2->addLink(nnode2);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 0);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(nnode1->ninc_, 0);
		UT_IS(nnode2->ninc_, 0);
	}
	// a fork
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		tnode1->addLink(nnode2);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 0);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(nnode1->ninc_, 0);
		UT_IS(nnode2->ninc_, 0);
	}
	// a join
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		tnode2->addLink(nnode1);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 0);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(nnode1->ninc_, 0);
		UT_IS(nnode2->ninc_, 0);
	}
	// a join and a straight (Y-shaped)
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *tnode3 = g.addTriead(t3);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		tnode2->addLink(nnode1);
		nnode1->addLink(tnode3);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 0);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(tnode3->ninc_, 0);
		UT_IS(nnode1->ninc_, 0);
		UT_IS(nnode2->ninc_, 0);
	}
	// a diamond
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		tnode1->addLink(nnode2);
		nnode1->addLink(tnode2);
		nnode2->addLink(tnode2);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 0);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(nnode1->ninc_, 0);
		UT_IS(nnode2->ninc_, 0);
	}
	// an X
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *tnode3 = g.addTriead(t3);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		tnode2->addLink(nnode1);
		nnode1->addLink(tnode3);
		nnode1->addLink(nnode2); // not realistic but doesn't matter here

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 0);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(tnode3->ninc_, 0);
		UT_IS(nnode1->ninc_, 0);
		UT_IS(nnode2->ninc_, 0);
	}
	// a simple loop
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		nnode1->addLink(tnode1);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 1);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(nnode1->ninc_, 1);
		UT_IS(nnode2->ninc_, 0);
	}
	// a simple loop with a tail
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		nnode1->addLink(tnode1);
		nnode1->addLink(tnode2);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 1);
		UT_IS(tnode2->ninc_, 1); // tail will stay
		UT_IS(nnode1->ninc_, 1);
		UT_IS(nnode2->ninc_, 0);
	}
	// a simple loop with a incoming links
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		nnode1->addLink(tnode1);
		tnode2->addLink(nnode1);
		nnode2->addLink(tnode1);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 1);
		UT_IS(tnode2->ninc_, 0);
		UT_IS(nnode1->ninc_, 1);
		UT_IS(nnode2->ninc_, 0);
	}
	// a longer loop
	{
		AppGuts::Graph g;
		AppGuts::NxTr *tnode1 = g.addTriead(t1);
		AppGuts::NxTr *tnode2 = g.addTriead(t2);
		AppGuts::NxTr *nnode1 = g.addNexus(nx1);
		AppGuts::NxTr *nnode2 = g.addNexus(nx2);

		tnode1->addLink(nnode1);
		nnode1->addLink(tnode2);
		tnode2->addLink(nnode2);
		nnode2->addLink(tnode1);

		AppGuts::reduceGraphL(g);

		UT_IS(tnode1->ninc_, 1);
		UT_IS(tnode2->ninc_, 1);
		UT_IS(nnode1->ninc_, 1);
		UT_IS(nnode2->ninc_, 1);
	}
	// a horizontal figure 8 of 2 diamonds
	{
		AppGuts::Graph g;

		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addTriead(t1)->addLink(g.addNexus(nx2));
		g.addNexus(nx1)->addLink(g.addTriead(t2));
		g.addNexus(nx2)->addLink(g.addTriead(t2));

		g.addTriead(t3)->addLink(g.addNexus(nx2));
		g.addTriead(t3)->addLink(g.addNexus(nx3));
		g.addNexus(nx2)->addLink(g.addTriead(t4));
		g.addNexus(nx3)->addLink(g.addTriead(t4));

		AppGuts::reduceGraphL(g);

		UT_IS(g.addTriead(t1)->ninc_, 0);
		UT_IS(g.addTriead(t2)->ninc_, 0);
		UT_IS(g.addTriead(t3)->ninc_, 0);
		UT_IS(g.addTriead(t4)->ninc_, 0);
		UT_IS(g.addNexus(nx1)->ninc_, 0);
		UT_IS(g.addNexus(nx2)->ninc_, 0);
		UT_IS(g.addNexus(nx3)->ninc_, 0);
	}
	// a vertical figure 8 of 2 diamonds
	{
		AppGuts::Graph g;

		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addTriead(t1)->addLink(g.addNexus(nx2));
		g.addNexus(nx1)->addLink(g.addTriead(t2));
		g.addNexus(nx2)->addLink(g.addTriead(t2));

		g.addTriead(t2)->addLink(g.addNexus(nx3));
		g.addTriead(t2)->addLink(g.addNexus(nx4));
		g.addNexus(nx3)->addLink(g.addTriead(t3));
		g.addNexus(nx4)->addLink(g.addTriead(t3));

		AppGuts::reduceGraphL(g);

		UT_IS(g.addTriead(t1)->ninc_, 0);
		UT_IS(g.addTriead(t2)->ninc_, 0);
		UT_IS(g.addTriead(t3)->ninc_, 0);
		UT_IS(g.addTriead(t4)->ninc_, 0);
		UT_IS(g.addNexus(nx1)->ninc_, 0);
		UT_IS(g.addNexus(nx2)->ninc_, 0);
		UT_IS(g.addNexus(nx3)->ninc_, 0);
		UT_IS(g.addNexus(nx4)->ninc_, 0);
	}
	
	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow2->markDead();
	ow3->markDead();
	ow4->markDead();
	a1->harvester(false);

	restore_uncatchable();
}

UTESTCASE check_graph(Utest *utest)
{
	make_catchable();

	Autoref<AppGuts> a1 = (AppGuts *)App::make("a1").get();

	// these threads and nexuses will be just used as graph fodder,
	// nothing more;
	// the connections don't matter because the graphs will be connected manually
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	Triead *t1 = ow1->get();
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
	Triead *t2 = ow2->get();
	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
	Triead *t3 = ow3->get();
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t4");
	Triead *t4 = ow4->get();

	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	Nexus *nx1 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx1")->addLabel("one", rt1)))->nexus();
	Nexus *nx2 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx2")->addLabel("one", rt1)))->nexus();
	Nexus *nx3 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx3")->addLabel("one", rt1)))->nexus();
	Nexus *nx4 = ow1->exportNexus(Facet::makeReader(
		FnReturn::make(ow1->unit(), "nx4")->addLabel("one", rt1)))->nexus();

	// a disconnected graph
	{
		AppGuts::Graph g;
		g.addTriead(t1);
		g.addTriead(t2);
		g.addTriead(t3);
		g.addTriead(t4);
		g.addNexus(nx1);
		g.addNexus(nx2);
		g.addNexus(nx3);
		g.addNexus(nx4);

		a1->checkGraphL(g, "direct");
	}
	// a diamond
	{
		AppGuts::Graph g;
		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addTriead(t1)->addLink(g.addNexus(nx2));
		g.addNexus(nx1)->addLink(g.addTriead(t2));
		g.addNexus(nx2)->addLink(g.addTriead(t2));

		a1->checkGraphL(g, "direct");
	}
	// a diamond with a tail
	{
		AppGuts::Graph g;
		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addTriead(t1)->addLink(g.addNexus(nx2));
		g.addNexus(nx1)->addLink(g.addTriead(t2));
		g.addNexus(nx2)->addLink(g.addTriead(t2));
		g.addTriead(t2)->addLink(g.addNexus(nx3));

		a1->checkGraphL(g, "direct");
	}
	// a horizontal figure 8
	{
		AppGuts::Graph g;
		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addTriead(t1)->addLink(g.addNexus(nx2));
		g.addNexus(nx1)->addLink(g.addTriead(t2));
		g.addNexus(nx2)->addLink(g.addTriead(t2));

		g.addTriead(t3)->addLink(g.addNexus(nx2));
		g.addTriead(t3)->addLink(g.addNexus(nx3));
		g.addNexus(nx2)->addLink(g.addTriead(t4));
		g.addNexus(nx3)->addLink(g.addTriead(t4));

		a1->checkGraphL(g, "direct");
	}
	// a vertical figure 8 of 2 diamonds
	{
		AppGuts::Graph g;

		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addTriead(t1)->addLink(g.addNexus(nx2));
		g.addNexus(nx1)->addLink(g.addTriead(t2));
		g.addNexus(nx2)->addLink(g.addTriead(t2));

		g.addTriead(t2)->addLink(g.addNexus(nx3));
		g.addTriead(t2)->addLink(g.addNexus(nx4));
		g.addNexus(nx3)->addLink(g.addTriead(t3));
		g.addNexus(nx4)->addLink(g.addTriead(t3));

		a1->checkGraphL(g, "direct");
	}
	// a simple loop
	{
		AppGuts::Graph g;
		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addNexus(nx1)->addLink(g.addTriead(t1));

		{
			string msg;
			try {
				a1->checkGraphL(g, "direct");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, 
				"In application 'a1' detected an illegal direct loop:\n"
				"  thread 't1'\n"
				"  nexus 't1/nx1'\n");
		}
	}
#if 0
	// a longer loop
	{
		AppGuts::Graph g;
		g.addTriead(t1)->addLink(g.addNexus(nx1));
		g.addNexus(nx1)->addLink(g.addTriead(t2));
		g.addTriead(t2)->addLink(g.addNexus(nx2));
		g.addNexus(nx2)->addLink(g.addTriead(t1));

		{
			string msg;
			try {
				a1->checkGraphL(g, "direct");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, 
				"In application 'a1' detected an illegal direct loop:\n"
				"  thread 't1'\n"
				"  nexus 't1/nx1'\n"
				"  thread 't2'\n"
				"  nexus 't1/nx2'\n");
		}
	}
#endif
	
	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow2->markDead();
	ow3->markDead();
	ow4->markDead();
	a1->harvester(false);

	restore_uncatchable();
}
