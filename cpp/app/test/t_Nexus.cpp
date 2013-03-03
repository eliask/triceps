//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the nexus-related calls in App and Trieads.

#include <assert.h>
#include <utest/Utest.h>
#include <type/AllTypes.h>
#include "AppTest.h"

// Facet construction
UTESTCASE make_facet(Utest *utest)
{
	make_catchable();

	// a simple test of static method
	UT_IS(Facet::buildFullName("a", "b"), "a/b");

	// prepare fragments
	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	Autoref<App> a1 = App::make("a1");
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");

	Autoref<Unit> unit1 = ow1->unit();

	// With an uninitialized FnReturn
	Autoref<FnReturn> fret1 = FnReturn::make(unit1, "fret1")
		->addLabel("one", rt1)
		->addLabel("two", rt1)
		->addLabel("three", rt1)
	;
	UT_ASSERT(!fret1->isInitialized());
	Autoref<Facet> fa1 = Facet::make(fret1, false); // reader
	// this initializes the fret
	UT_ASSERT(fret1->isInitialized());
	UT_ASSERT(!fa1->isWriter());

	UT_IS(fa1->getFnReturn(), fret1);
	UT_IS(fa1->getShortName(), "fret1");
	UT_IS(fa1->getFullName(), ""); // empty until exported
	UT_ASSERT(!fa1->isImported());

	// the reverse mode is more interesting for reimport
	fa1->setReverse();
	UT_ASSERT(fa1->isReverse());
	UT_IS(fa1->queueLimit(), Facet::DEFAULT_QUEUE_LIMIT);
	
	// reuse the same FnReturn, which is now initialized
	Autoref<Facet> fa2 = Facet::make(fret1, true); // writer
	UT_ASSERT(fa2->isWriter());

	UT_ASSERT(!fa2->isUnicast());
	fa2->setUnicast();
	UT_ASSERT(fa2->isUnicast());

	UT_ASSERT(!fa2->isReverse());
	fa2->setReverse();
	UT_ASSERT(fa2->isReverse());

	UT_ASSERT(fa2->isUnicast());
	fa2->setUnicast(false);
	UT_ASSERT(!fa2->isUnicast());

	UT_ASSERT(fa2->isReverse());
	fa2->setReverse(false);
	UT_ASSERT(!fa2->isReverse());

	UT_IS(fa2->queueLimit(), Facet::DEFAULT_QUEUE_LIMIT);
	fa2->setQueueLimit(100);
	UT_IS(fa2->queueLimit(), 100);

	// test the convenience wrappers
	Autoref<Facet> fa3 = Facet::makeReader(fret1);
	UT_ASSERT(!fa3->isWriter());
	Autoref<Facet> fa4 = Facet::makeWriter(fret1);
	UT_ASSERT(fa4->isWriter());
	
	// add more row types
	UT_IS(fa1->rowTypes().size(), 0);
	UT_IS(fa1->exportRowType("rt1", rt1), fa1.get());
	fa1->exportRowType("rt2", rt1);
	UT_IS(fa1->rowTypes().size(), 2);
	UT_IS(fa1->rowTypes().at("rt1"), rt1);
	UT_IS(fa1->rowTypes().at("rt2"), rt1);

	// add more table types
	Autoref<TableType> tt1 = TableType::make(rt1)
		->addSubIndex("primary", HashedIndexType::make(
			NameSet::make()->add("a")->add("e")))
	;
	UT_IS(fa1->tableTypes().size(), 0);
	UT_IS(fa1->exportTableType("tt1", tt1), fa1.get());
	fa1->exportTableType("tt2", tt1);
	UT_IS(fa1->tableTypes().size(), 2);
	UT_IS(fa1->tableTypes().at("tt1"), tt1);
	UT_IS(fa1->tableTypes().at("tt2"), tt1);

	// the basic export with reimport sets a bunch of things
	Autoref<Facet> fa1im = ow1->exportNexus(fa1);
	UT_IS(fa1im, fa1);
	UT_ASSERT(fa1->isImported());
	UT_IS(fa1->getFullName(), "t1/fret1");
	UT_IS(fa1->getShortName(), "fret1");
	UT_IS(fa1->queueLimit(), Xtray::QUE_ID_MAX);

	// an invalid FnReturn
	{
		Erref err;

		Autoref<FnReturn> fretbad = FnReturn::make(unit1, "fretbad")
			->addLabel("one", rt1)
			->addLabel("one", rt1)
		;
		err = fretbad->getErrors();
		UT_ASSERT(err->hasError());
		UT_IS(err->print(), "duplicate row name 'one'\n");

		Autoref<Facet> fabad = Facet::makeReader(fretbad);
		err = fabad->getErrors();
		UT_ASSERT(err->hasError());
		UT_IS(err->print(), "Errors in the underlying FnReturn:\n  duplicate row name 'one'\n");

		// the exception gets thrown at export attempt
		{
			string msg;
			try {
				ow1->exportNexus(fabad);
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, 
				"In app 'a1' thread 't1' can not export the facet 'fretbad' with an error:\n"
				"  Errors in the underlying FnReturn:\n"
				"    duplicate row name 'one'\n");
		}
	}

	// an FnReturn that already has an xtray
	{
		Erref err;

		Autoref<FnReturn> fretbad = FnReturn::make(unit1, "fretbad")
			->addLabel("one", rt1)
			->addLabel("two", rt1)
		;
		err = fretbad->getErrors();
		UT_ASSERT(!err->hasError());

		fretbad->initialize();
		Autoref<Xtray> xt1 = new Xtray(fretbad->getType());
		FnReturnGuts::swapXtray(fretbad, xt1);
		UT_ASSERT(fretbad->isFaceted());

		{
			Autoref<Facet> fabad = Facet::makeWriter(fretbad); // can't use a faceted FnReturn for a writer
			err = fabad->getErrors();
			UT_ASSERT(err->hasError());
			UT_IS(err->print(), "The FnReturn is already connected to a writer facet, can not do it twice.\n");

			UT_ASSERT(!fabad->isWriter()); // this error resets the writer flag

			// the exception gets thrown at export attempt
			{
				string msg;
				try {
					ow1->exportNexus(fabad);
				} catch(Exception e) {
					msg = e.getErrors()->print();
				}
				UT_IS(msg, 
					"In app 'a1' thread 't1' can not export the facet 'fretbad' with an error:\n"
					"  The FnReturn is already connected to a writer facet, can not do it twice.\n");
			}
		}

		// After the Facet with this error is destroyed, the FnReturn must stay faceted
		UT_ASSERT(fretbad->isFaceted());

		{
			// however that same FnReturn with Xtray can be used fine for a reader
			Autoref<Facet> fagood = Facet::makeReader(fretbad);
			UT_ASSERT(!fagood->getErrors()->hasError());
		}
		
		// After the reader Facet is destroyed, the FnReturn must stay faceted
		UT_ASSERT(fretbad->isFaceted());
	}

	// rowType failures
	{
		Autoref<Facet> fabad;

		fabad = Facet::make(fret1, true);
		UT_IS(fabad->exportRowType("rta", NULL), fabad);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), "Can not export a NULL row type with name 'rta'.\n");

		fabad = Facet::make(fret1, true);
		fabad->exportRowType("", rt1);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), "Can not export a row type with an empty name.\n");

		fabad = Facet::make(fret1, true);
		fabad->setQueueLimit(0);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), "Can not set the queue size limit to 0, must be greater than 0.\n");

		fabad = Facet::make(fret1, true);
		fabad->exportRowType("rt1", rt1); // this one is OK
		fabad->exportRowType("rt1", rt1);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), "Can not export a duplicate row type name 'rt1'.\n");

		fabad = Facet::make(fret1, true);
		RowType::FieldVec fld;
		mkfields(fld);
		fld[1].name_ = "a"; // a duplicate name
		Autoref<RowType> rtbad = new CompactRowType(fld);
		UT_ASSERT(rtbad->getErrors()->hasError());
		fabad->exportRowType("rtb", rtbad);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), 
			"Can not export a row type 'rtb' containing errors:\n"
			"  duplicate field name 'a' for fields 2 and 1\n");
	}

	// tableType failures
	{
		Autoref<Facet> fabad;

		fabad = Facet::make(fret1, true);
		UT_IS(fabad->exportTableType("tta", NULL), fabad);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), "Can not export a NULL table type with name 'tta'.\n");

		fabad = Facet::make(fret1, true);
		fabad->exportTableType("", tt1);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), "Can not export a table type with an empty name.\n");

		fabad = Facet::make(fret1, true);
		fabad->exportTableType("tt1", tt1); // this one is OK
		fabad->exportTableType("tt1", tt1);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), "Can not export a duplicate table type name 'tt1'.\n");

		fabad = Facet::make(fret1, true);
		RowType::FieldVec fld;
		mkfields(fld);
		fld[1].name_ = "a"; // a duplicate name
		Autoref<RowType> rtbad = new CompactRowType(fld);
		UT_ASSERT(rtbad->getErrors()->hasError());
		Autoref<TableType> ttbad = TableType::make(rtbad)
			->addSubIndex("primary", HashedIndexType::make(
				NameSet::make()->add("a")->add("e")))
		;
		fabad->exportTableType("ttb", ttbad);
		UT_ASSERT(fabad->getErrors()->hasError());
		UT_IS(fabad->getErrors()->print(), 
			"Can not export a table type 'ttb' containing errors:\n"
			"  row type error:\n"
			"    duplicate field name 'a' for fields 2 and 1\n");
	}

	// can not modify an imported Facet
	{
		string msg;
		try {
			fa1->setReverse();
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempted to modify an imported facet 't1/fret1'.\n");
	}
	{
		string msg;
		try {
			fa1->setUnicast();
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempted to modify an imported facet 't1/fret1'.\n");
	}
	{
		string msg;
		try {
			fa1->setQueueLimit(100);
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempted to modify an imported facet 't1/fret1'.\n");
	}
	{
		string msg;
		try {
			fa1->exportRowType("rtx", rt1);
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempted to modify an imported facet 't1/fret1'.\n");
	}
	{
		string msg;
		try {
			fa1->exportTableType("ttx", tt1);
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempted to modify an imported facet 't1/fret1'.\n");
	}

	// clean-up, since the apps catalog is global
	ow1->markDead();
	a1->harvester();

	restore_uncatchable();
}

UTESTCASE export_import(Utest *utest)
{
	make_catchable();

	Autoref<FnReturn> fret3; // will be used to check facet destruction
	{
		Autoref<App> a1 = App::make("a1");
		a1->setTimeout(0); // will replace all waits with an Exception
		Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
		Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
		Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
		Autoref<TrieadOwner> ow4 = a1->makeTriead("t3/a"); // with a screwy name

		Triead::NexusMap exp;
		Triead::FacetMap imp;

		// initially no imports, no exports
		ow1->imports(imp);
		UT_ASSERT(imp.empty());
		ow1->get()->exports(exp);
		UT_ASSERT(exp.empty());

		// prepare fragments
		RowType::FieldVec fld;
		mkfields(fld);
		Autoref<RowType> rt1 = new CompactRowType(fld);

		Autoref<Unit> unit1 = ow1->unit();

		// With an uninitialized FnReturn
		Autoref<FnReturn> fret1 = FnReturn::make(unit1, "fret1")
			->addLabel("one", rt1)
			->addLabel("two", rt1)
			->addLabel("three", rt1)
		;
		Autoref<Facet> fa1 = Facet::makeReader(fret1)->setQueueLimit(100);

		// basic export of a reader with reimport
		Autoref<Facet> fa1im = ow1->exportNexus(fa1);
		UT_IS(fa1im, fa1);
		UT_ASSERT(fa1->isImported());
		UT_IS(fa1->queueLimit(), 100);

		ow1->imports(imp);
		UT_IS(imp.size(), 1);
		UT_IS(imp["t1/fret1"], fa1);

		ow1->get()->imports(exp); // test the list of imports from Triead
		UT_IS(exp.size(), 1);
		UT_IS(exp["t1/fret1"].get(), fa1->nexus());

		ow1->exports(exp);
		UT_IS(exp.size(), 1);
		UT_IS(exp["fret1"].get(), fa1->nexus());

		UT_ASSERT(!fa1->getFnReturn()->isFaceted()); // reader doesn't add xtray to the FnReturn

		// basic export with no reimport
		Autoref<FnReturn> fret2 = FnReturn::make(unit1, "fret2")
			->addLabel("one", rt1)
		;
		Autoref<Facet> fa2 = Facet::makeReader(fret2)
			->setReverse()->setQueueLimit(100); // limit would not change with no reimport
		Autoref<Facet> fa2im = ow1->exportNexusNoImport(fa2);
		UT_IS(fa2im, fa2);
		UT_ASSERT(!fa2->isImported());
		UT_ASSERT(fa2->nexus() == NULL);
		UT_ASSERT(fa2->getFullName().empty());
		UT_IS(fa2->queueLimit(), 100);

		UT_ASSERT(!fa2->getFnReturn()->isFaceted()); // reader doesn't add xtray to the FnReturn

		ow1->imports(imp);
		UT_IS(imp.size(), 1);

		ow1->exports(exp);
		UT_IS(exp.size(), 2);
		UT_IS(exp["fret2"].get()->getName(), "fret2");

		// import into the same thread, works immediately
		Autoref<Facet> fa3 = ow1->importNexus("t1", "fret2", "fret3", true);
		UT_ASSERT(fa3->getFnReturn()->equals(fa2->getFnReturn()));
		UT_IS(fa3->getFnReturn()->getUnitPtr(), ow1->unit());

		UT_IS(fa3->queueLimit(), Xtray::QUE_ID_MAX); // on import the limit is set to max for reverse nexus
		
		fret3 = fa3->getFnReturn();
		UT_ASSERT(fret3->isFaceted()); // writer adds xtray to the FnReturn

		ow1->imports(imp);
		UT_IS(imp.size(), 2);
		UT_IS(imp["t1/fret2"], fa3);

		// an import into another thread would wait for thread to be fully constructed
		// (and in this case fail on timeout)
		{
			string msg;
			try {
				ow2->importReader("t1", "fret2");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "Thread 't1' in application 'a1' did not initialize within the deadline.\n");
		}

		// an immediate import into another thread would succeed
		Autoref<Facet> fa4 = ow2->importReaderImmed("t1", "fret2");
		UT_ASSERT(fa4->getFnReturn()->equals(fa2->getFnReturn()));
		UT_IS(fa4->nexus(), fa3->nexus());
		UT_IS(fa4->getShortName(), "fret2");
		UT_IS(fa4->getFnReturn()->getUnitPtr(), ow2->unit());
		
		UT_ASSERT(!fa4->getFnReturn()->isFaceted()); // reader doesn't add xtray to the FnReturn

		ow2->imports(imp);
		UT_IS(imp.size(), 1);
		UT_IS(imp["t1/fret2"], fa4);

		// test importWriterImmed success
		Autoref<Facet> fa5 = ow3->importWriterImmed("t1", "fret2", "fff");
		UT_ASSERT(fa5->getFnReturn()->equals(fa2->getFnReturn()));
		UT_IS(fa5->nexus(), fa3->nexus());
		UT_IS(fa5->getShortName(), "fff");
		
		UT_ASSERT(fa5->getFnReturn()->isFaceted()); // writer adds xtray to the FnReturn

		ow3->imports(imp);
		UT_IS(imp.size(), 1);
		UT_IS(imp["t1/fret2"], fa5);

		// a repeated import succeeds immediately even if it's not marked as such
		Autoref<Facet> fa6 = ow3->importWriter("t1", "fret2", "xxx");
		UT_IS(fa6, fa5); // same, ignoring the asname!
		ow3->imports(imp);
		UT_IS(imp.size(), 1);

		UT_ASSERT(fa6->getFnReturn()->isFaceted()); // writer adds xtray to the FnReturn

		// errors
		// exporting a facet with an error already tested in make_facet()
		{
			string msg;
			try {
				ow2->exportNexus(fa4);
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "In app 'a1' thread 't2' can not re-export the imported facet 't1/fret2'.\n");
		}
		{
			string msg;
			try {
				ow3->importReader("t1", "fret2", "xxx");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "In app 'a1' thread 't3' can not import the nexus 't1/fret2' for both reading and writing.\n");
		}
		{
			string msg;
			try {
				ow3->importReaderImmed("t1", "fret99", "xxx");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "For thread 't3', the nexus 'fret99' is not found in application 'a1' thread 't1'.\n");
		}
		{
			string msg;
			try {
				ow1->exportNexusNoImport(fa2);
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "Can not export the nexus with duplicate name 'fret2' in app 'a1' thread 't1'.\n");
		}
		{
			string msg;

			Autoref<FnReturn> fretm1 = FnReturn::make(ow3->unit(), "a/nex") // a acrewy name
				->addLabel("one", rt1)
			;
			ow3->exportNexus(Facet::makeReader(fretm1)); // also tests the reference passing as the argument
			ow4->importReaderImmed("t3", "a/nex"); // has full name "t3/a/nex"
			
			Autoref<FnReturn> fretm2 = FnReturn::make(ow4->unit(), "nex")
				->addLabel("one", rt1)
			;

			try {
				ow4->exportNexus(Facet::makeReader(fretm2));
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "On exporting a facet in app 'a1' found a same-named facet 't3/a/nex' already imported, did you mess with the funny names?\n");
		}
		{
			string msg;

			Autoref<FnReturn> fretx = FnReturn::make(unit1, "faceted")
				->addLabel("one", rt1)
			;

			Autoref<Facet> fax = Facet::makeWriter(fretx);

			// mess with the Xtray after the facet hasbeen constructed
			Autoref<Xtray> xtx = new Xtray(fretx->getType());
			FnReturnGuts::swapXtray(fretx, xtx);
			UT_ASSERT(fretx->isFaceted());

			try {
				ow2->exportNexus(fax);
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "The FnReturn 'faceted' in thread 't2' is already connected to a writer facet, can not do it twice.\n");
		}
		{
			string msg;

			ow1->markConstructed();
			Autoref<FnReturn> fretm1 = FnReturn::make(ow1->unit(), "more")
				->addLabel("one", rt1)
			;

			try {
				ow1->exportNexus(Facet::makeReader(fretm1));
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "Can not export the nexus 'more' in app 'a1' thread 't1' that is already marked as constructed.\n");
		}
		{
			string msg;
			ow4->markReady();
			try {
				ow4->importReader("t1", "fret2", "xxx");
			} catch(Exception e) {
				msg = e.getErrors()->print();
			}
			UT_IS(msg, "In app 'a1' thread 't3/a' can not import the nexus 't1/fret2' into a ready thread.\n");
		}

		// the other mess
		{
			// basic export of a reader with reimport works fine even if the FnReturn is faceted
			Autoref<FnReturn> fret7 = FnReturn::make(unit1, "fret7")
				->addLabel("one", rt1)
			;
			fret7->initialize();
			Autoref<Xtray> xt7 = new Xtray(fret7->getType());
			FnReturnGuts::swapXtray(fret7, xt7);
			UT_ASSERT(fret7->isFaceted());

			Autoref<Facet> fa7 = Facet::makeReader(fret7);

			ow2->exportNexus(fa7);
			UT_ASSERT(fa7->isImported());

			// basic export of a writer with reimport
			Autoref<FnReturn> fret8 = FnReturn::make(unit1, "fret8")
				->addLabel("one", rt1)
			;
			fret8->initialize();
			UT_ASSERT(!fret8->isFaceted());

			Autoref<Facet> fa8 = Facet::makeWriter(fret8);

			ow2->exportNexus(fa8);
			UT_ASSERT(fa8->isImported());
			UT_ASSERT(fret8->isFaceted());

			// basic export of a writer with no reimport
			Autoref<FnReturn> fret9 = FnReturn::make(unit1, "fret9")
				->addLabel("one", rt1)
			;
			fret9->initialize();
			UT_ASSERT(!fret9->isFaceted());

			Autoref<Facet> fa9 = Facet::makeWriter(fret9);

			ow2->exportNexusNoImport(fa9);
			UT_ASSERT(!fa9->isImported());
			UT_ASSERT(!fret9->isFaceted()); // not faceted if not reimported
		}

		// clean-up, since the apps catalog is global
		ow1->markDead();
		ow2->markDead();
		ow3->markDead();
		ow4->markDead();
		a1->harvester();
	}

	// After a Facet is destroyed, its FnReturn must lose the Xtray.
	UT_ASSERT(!fret3->isFaceted());

	restore_uncatchable();
}

// copied from t_Fn.cpp
class MyFnCtx: public FnContext
{
public:
	MyFnCtx():
		pushes_(0),
		pops_(0),
		throws_(false)
	{ }

	virtual void onPush(const FnReturn *fret)
	{
		fret_ = fret;
		if (throws_)
			throw Exception::f("push exception");
		++pushes_;
	}

	virtual void onPop(const FnReturn *fret)
	{
		fret_ = fret;
		if (throws_)
			throw Exception::f("pop exception");
		++pops_;
	}

	int pushes_, pops_;
	bool throws_;
	const FnReturn *fret_;
};

// the helper interface
UTESTCASE mknexus(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");
	a1->setTimeout(0); // will replace all waits with an Exception
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t3/a"); // with a screwy name

	Triead::NexusMap exp;
	Triead::FacetMap imp;

	// prepare fragments
	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	Autoref<Label> lb1 = new DummyLabel(ow1->unit(), rt1, "lb1");
	Autoref<MyFnCtx> ctx1 = new MyFnCtx;

	// build a writer, with all the trimmings
	{
		Autoref<Facet> fa1 = ow1->makeNexusWriter("nx1")
			->addLabel("one", rt1)
			->addFromLabel("two", lb1)
			->setContext(ctx1)
			->setUnicast()
			->setUnicast(true)
			->setReverse()
			->setReverse(true)
			->setQueueLimit(3)
			->complete();

		UT_ASSERT(fa1->isImported());
		UT_ASSERT(fa1->isWriter());
		UT_ASSERT(fa1->isUnicast());
		UT_ASSERT(fa1->isReverse());
		UT_IS(fa1->queueLimit(), Xtray::QUE_ID_MAX); // auto-set for reverse
		UT_IS(fa1->getShortName(), "nx1");
		UT_IS(fa1->getFullName(), "t1/nx1");
		UT_IS(fa1->getFnReturn()->context(), ctx1);

		ow1->imports(imp);
		UT_IS(imp.size(), 1);
		UT_IS(imp["t1/nx1"], fa1);

		ow1->exports(exp);
		UT_IS(exp.size(), 1);
		UT_IS(exp["nx1"].get(), fa1->nexus());

		// the maker gets reset to NULL after completion
		UT_IS(TrieadOwnerGuts::nexusMakerFnReturn(ow1), NULL);
		UT_IS(TrieadOwnerGuts::nexusMakerFacet(ow1), NULL);
	}

	// build a reader
	{
		Autoref<Facet> fa1 = ow1->makeNexusReader("nx2")
			->addLabel("one", rt1)
			->complete();

		UT_ASSERT(fa1->isImported());
		UT_ASSERT(!fa1->isWriter());
	}

	{
		// build a no-import
		Autoref<Facet> fa1 = ow1->makeNexusNoImport("nx3")
			->addLabel("one", rt1)
			->complete();

		UT_ASSERT(!fa1->isImported());
	}

	{
		// incorrect initialization order
		string msg;
		try {
			Autoref<Facet> fa1 = ow1->makeNexusWriter("nx4")
				->setUnicast()
				->addLabel("one", rt1)
				->complete();
		} catch(Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Attempted to add label 'one' to an initialized FnReturn 'nx4'.\n");
	}

	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow2->markDead();
	ow3->markDead();
	ow4->markDead();
	a1->harvester();

	restore_uncatchable();
}

// check the connection of queues done when importing facets
UTESTCASE import_queues(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");
	a1->setTimeout(0); // will replace all waits with an Exception
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");
	Autoref<TrieadOwner> ow3 = a1->makeTriead("t3");
	Autoref<TrieadOwner> ow4 = a1->makeTriead("t3/a"); // with a screwy name

	// prepare fragments
	RowType::FieldVec fld;
	mkfields(fld);
	Autoref<RowType> rt1 = new CompactRowType(fld);

	Autoref<Unit> unit1 = ow1->unit();

	// start with a writer
	Autoref<Facet> fa1 = ow1->makeNexusWriter("nx1")
		->addLabel("one", rt1)
		->addLabel("two", rt1)
		->addLabel("three", rt1)
		->complete()
	;
	Nexus *nx1 = fa1->nexus();
	Nexus::WriterVec *wv;

	UT_ASSERT(FacetGuts::readerQueue(fa1) == NULL);
	UT_ASSERT(FacetGuts::nexusWriter(fa1) != NULL);

	ReaderVec *rv1 = NexusGuts::readers(nx1);
	wv = NexusGuts::writers(nx1);

	UT_IS(rv1, NULL);
	UT_IS(wv->size(), 1);
	UT_IS(FacetGuts::nexusWriter(fa1), wv->at(0));
	UT_IS(NexusWriterGuts::readers(wv->at(0)), NULL);
	UT_IS(NexusWriterGuts::readersNew(wv->at(0)), NULL);

	ow1->markReady(); // make the nexus visible for import

	// add a reader
	Autoref<Facet> fa2 = ow2->importReader("t1", "nx1", "");

	UT_ASSERT(FacetGuts::readerQueue(fa2) != NULL);
	UT_ASSERT(FacetGuts::nexusWriter(fa2) == NULL);

	UT_ASSERT(!ReaderQueueGuts::isDead(FacetGuts::readerQueue(fa2)));

	ReaderVec *rv2 = NexusGuts::readers(nx1);

	UT_ASSERT(rv2 != NULL);
	UT_ASSERT(rv2 != rv1);
	UT_IS(rv2->v().size(), 1);
	UT_IS(wv->size(), 1);
	UT_IS(NexusWriterGuts::readers(wv->at(0)), NULL);
	UT_IS(NexusWriterGuts::readersNew(wv->at(0)), rv2);
	UT_IS(rv2->gen(), 0);
	UT_IS(rv2->v()[0].get(), FacetGuts::readerQueue(fa2));
	UT_IS(ReaderQueueGuts::gen(rv2->v()[0]), 0);

	// add another reader
	Autoref<Facet> fa3 = ow3->importReader("t1", "nx1", "");

	UT_ASSERT(FacetGuts::readerQueue(fa3) != NULL);
	UT_ASSERT(FacetGuts::nexusWriter(fa3) == NULL);

	UT_ASSERT(!ReaderQueueGuts::isDead(FacetGuts::readerQueue(fa3)));

	ReaderVec *rv3 = NexusGuts::readers(nx1);

	UT_ASSERT(rv3 != NULL);
	UT_ASSERT(rv3 != rv2);
	UT_IS(rv3->v().size(), 2);
	UT_IS(wv->size(), 1);
	UT_IS(NexusWriterGuts::readers(wv->at(0)), NULL);
	UT_IS(NexusWriterGuts::readersNew(wv->at(0)), rv3);
	UT_IS(rv3->gen(), 1);
	UT_IS(rv3->v()[0].get(), FacetGuts::readerQueue(fa2));
	UT_IS(rv3->v()[1].get(), FacetGuts::readerQueue(fa3));
	UT_IS(ReaderQueueGuts::gen(rv3->v()[0]), 1);
	UT_IS(ReaderQueueGuts::gen(rv3->v()[1]), 1);

	// add another writer
	Autoref<Facet> fa4 = ow4->importWriter("t1", "nx1", "");

	UT_ASSERT(FacetGuts::readerQueue(fa4) == NULL);
	UT_ASSERT(FacetGuts::nexusWriter(fa4) != NULL);

	ReaderVec *rv4 = NexusGuts::readers(nx1);

	UT_ASSERT(rv4 != NULL);
	UT_ASSERT(rv4 == rv3);
	UT_IS(rv4->v().size(), 2);
	UT_IS(wv->size(), 2);
	UT_IS(FacetGuts::nexusWriter(fa1), wv->at(0));
	UT_IS(FacetGuts::nexusWriter(fa4), wv->at(1));
	UT_IS(NexusWriterGuts::readers(wv->at(1)), NULL);
	UT_IS(NexusWriterGuts::readersNew(wv->at(1)), rv4);
	UT_IS(rv4->gen(), 1);

	// ----------------------------------------------------------------------
	// Test the manual calls for deletion of readers and writers
	// (they are not normally accessible to the users).

	// delete the first reader
	NexusGuts::deleteReader(nx1, FacetGuts::readerQueue(fa2));

	ReaderVec *rvx2 = NexusGuts::readers(nx1);

	UT_ASSERT(rvx2 != NULL);
	UT_IS(rvx2->v().size(), 1);
	UT_IS(wv->size(), 2);
	UT_IS(NexusWriterGuts::readers(wv->at(0)), NULL); // XXX will change
	UT_IS(NexusWriterGuts::readersNew(wv->at(0)), rvx2);
	UT_IS(rvx2->gen(), 2);
	UT_IS(rvx2->v()[0].get(), FacetGuts::readerQueue(fa3)); // shifted forward
	UT_IS(ReaderQueueGuts::gen(rvx2->v()[0]), 2);
	UT_ASSERT(ReaderQueueGuts::isDead(FacetGuts::readerQueue(fa2)));
	// XXX also check the queue cleaned in fa2
	// XXX also check the lastId in fa3

	// delete the second and last reader
	NexusGuts::deleteReader(nx1, FacetGuts::readerQueue(fa3));

	ReaderVec *rvx3 = NexusGuts::readers(nx1);

	UT_ASSERT(rvx3 != NULL);
	UT_IS(rvx3->v().size(), 0);
	UT_IS(wv->size(), 2);
	UT_IS(NexusWriterGuts::readers(wv->at(0)), NULL); // XXX will change
	UT_IS(NexusWriterGuts::readersNew(wv->at(0)), rvx3);
	UT_IS(rvx3->gen(), 3);
	UT_ASSERT(ReaderQueueGuts::isDead(FacetGuts::readerQueue(fa3)));
	// XXX also check the queue cleaned in fa3

	// delete the first writer
	NexusGuts::deleteWriter(nx1, FacetGuts::nexusWriter(fa1));
	UT_IS(wv->size(), 1);
	UT_IS(FacetGuts::nexusWriter(fa4), wv->at(0));

	// delete the second and last writer
	NexusGuts::deleteWriter(nx1, FacetGuts::nexusWriter(fa4));
	UT_IS(wv->size(), 0);

	// ----------------------------------------------------------------------
	
	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow2->markDead();
	ow3->markDead();
	ow4->markDead();
	a1->harvester();

	restore_uncatchable();
}
