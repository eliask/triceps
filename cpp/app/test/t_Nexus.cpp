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
	
	// reuse the same FnReturn, which is now initialized
	Autoref<Facet> fa2 = Facet::make(fret1, true); // writer
	UT_ASSERT(fa2->isWriter());

	// test the convenience wrappers
	Autoref<Facet> fa3 = Facet::makeReader(fret1);
	UT_ASSERT(!fa3->isWriter());
	Autoref<Facet> fa4 = Facet::makeWriter(fret1);
	UT_ASSERT(fa4->isWriter());
	
	// add more row types
	UT_IS(fa1->rowTypes().size(), 0);
	fa1->exportRowType("rt1", rt1);
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
	fa1->exportTableType("tt1", tt1);
	fa1->exportTableType("tt2", tt1);
	UT_IS(fa1->tableTypes().size(), 2);
	UT_IS(fa1->tableTypes().at("tt1"), tt1);
	UT_IS(fa1->tableTypes().at("tt2"), tt1);

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

		// the exception gets thrown at export attempt, so test that later
	}

	// clean-up, since the apps catalog is global
	ow1->markDead();
	a1->harvester();

	restore_uncatchable();
}

UTESTCASE export_import(Utest *utest)
{
	make_catchable();

	Autoref<App> a1 = App::make("a1");
	Autoref<TrieadOwner> ow1 = a1->makeTriead("t1");
	Autoref<TrieadOwner> ow2 = a1->makeTriead("t2");

	// export
	// XXX

	// clean-up, since the apps catalog is global
	ow1->markDead();
	ow2->markDead();
	a1->harvester();

	restore_uncatchable();
}
