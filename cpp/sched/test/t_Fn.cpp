//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of the streaming function.

#include <utest/Utest.h>
#include <string.h>

#include <sched/FnReturn.h>
#include <sched/Unit.h>
#include <type/CompactRowType.h>

// Make fields of all simple types
void mkfields(RowType::FieldVec &fields)
{
	fields.clear();
	fields.push_back(RowType::Field("a", Type::r_uint8, 10));
	fields.push_back(RowType::Field("b", Type::r_int32,0));
	fields.push_back(RowType::Field("c", Type::r_int64));
	fields.push_back(RowType::Field("d", Type::r_float64));
	fields.push_back(RowType::Field("e", Type::r_string));
}

UTESTCASE fn_return(Utest *utest)
{
	string msg;
	Exception::abort_ = false; // make them catchable
	Exception::enableBacktrace_ = false; // make the error messages predictable

	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit1 = new Unit("u");
	Autoref<Unit> unit2 = new Unit("u2");

	// make the components
	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());
	
	fld[2].type_ = Type::r_int32;
	Autoref<RowType> rt2 = new CompactRowType(fld);
	UT_ASSERT(rt2->getErrors().isNull());

	fld[0].name_ = "A";
	Autoref<RowType> rt3 = new CompactRowType(fld);
	UT_ASSERT(rt3->getErrors().isNull());

	Autoref<Label> lb1 = new DummyLabel(unit1, rt1, "lb1");
	Autoref<Label> lb1x = new DummyLabel(unit2, rt1, "lb1x");
	Autoref<Label> lb2 = new DummyLabel(unit1, rt2, "lb2");
	Autoref<Label> lb3 = new DummyLabel(unit1, rt3, "lb3");

	// make the returns

	// a good one
	Autoref<FnReturn> fret1 = FnReturn::make(unit1, "fret1")
		->addFromLabel("one", lb1)
		->addDummyLabel("two", rt2)
		->initialize();
	UT_ASSERT(fret1->getErrors().isNull());
	UT_ASSERT(fret1->isInitialized());
	// an equal one but not initialized
	Autoref<FnReturn> fret2 = FnReturn::make(unit1, "fret2")
		->addDummyLabel("one", rt1)
		->addDummyLabel("two", rt2);
	UT_ASSERT(fret2->getErrors().isNull());
	UT_ASSERT(!fret2->isInitialized());
	// a matching one
	Autoref<FnReturn> fret3 = FnReturn::make(unit1, "fret3")
		->addDummyLabel("one", rt1)
		->addDummyLabel("xxx", rt2)
		->initialize();
	UT_ASSERT(fret3->getErrors().isNull());
	
	// bad ones
	{
		Autoref<FnReturn> fretbad = FnReturn::make(unit1, "fretbad")
			->addDummyLabel("one", rt1)
			->addDummyLabel("", rt2)
			->initialize();
		UT_ASSERT(!fretbad->getErrors().isNull());
		UT_IS(fretbad->getErrors()->print(), "row name at position 2 must not be empty\n");
	}
	{
		Autoref<FnReturn> fretbad = FnReturn::make(unit1, "fretbad")
			->addDummyLabel("one", rt1)
			->addDummyLabel("one", rt2)
			->initialize();
		UT_ASSERT(!fretbad->getErrors().isNull());
		UT_IS(fretbad->getErrors()->print(), "duplicate row name 'one'\n");
	}
	{
		Autoref<FnReturn> fretbad = FnReturn::make(unit1, "fretbad")
			->addDummyLabel("one", (RowType *)NULL)
			->addDummyLabel("two", rt2)
			->initialize();
		UT_ASSERT(!fretbad->getErrors().isNull());
		UT_IS(fretbad->getErrors()->print(), "null row type with name 'one'\n");
	}
	{
		Autoref<FnReturn> fretbad = FnReturn::make(unit1, "fretbad")
			->addFromLabel("one", lb1x)
			->addDummyLabel("two", rt2)
			->initialize();
		UT_ASSERT(!fretbad->getErrors().isNull());
		UT_IS(fretbad->getErrors()->print(), "Can not include the label 'lb1x' into the FnReturn as 'one': it has a different unit, 'u2' vs 'u'.\n");
	}

	UT_ASSERT(fret1->equals(fret2));
	UT_ASSERT(fret2->equals(fret1));
	UT_ASSERT(!fret1->equals(fret3));
	UT_ASSERT(fret1->match(fret2));
	UT_ASSERT(fret1->match(fret3));

	// try to add to an initialized return
	{
		msg.clear();
		try {
			fret1->addDummyLabel("three", rt3);
		} catch (Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempt to add label 'three' to an initialized FnReturn.\n");
	}
	{
		msg.clear();
		try {
			fret1->addFromLabel("three", lb3);
		} catch (Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempt to add label 'three' to an initialized FnReturn.\n");
	}
	// try go get the type of uninitialized return
	{
		msg.clear();
		try {
			fret2->getType();
		} catch (Exception e) {
			msg = e.getErrors()->print();
		}
		UT_IS(msg, "Triceps API violation: attempt to get the type from an uninitialized FnReturn.\n");
	}

	// getters
	{
		const RowSetType::NameVec &names = fret1->getLabelNames();
		UT_IS(names.size(), 2);
		UT_IS(names[0], "one");
		UT_IS(names[1], "two");
	}
	{
		const RowSetType::RowTypeVec &types = fret1->getRowTypes();
		UT_IS(types.size(), 2);
		UT_IS(types[0].get(), rt1.get());
		UT_IS(types[1].get(), rt2.get());
	}

	UT_IS(fret1->size(), 2);

	RowSetType *rst1 = fret1->getType();
	UT_ASSERT(rst1 != NULL);
	UT_IS(rst1->size(), 2);

	UT_IS(fret1->findLabel("one"), 0);
	UT_IS(fret1->findLabel("two"), 1);
	UT_IS(fret1->findLabel("zzz"), -1);

	UT_IS(fret1->getRowType("one"), rt1.get());
	UT_IS(fret1->getRowType("two"), rt2.get());
	UT_IS(fret1->getRowType("zzz"), NULL);

	UT_IS(fret1->getRowType(0), rt1.get());
	UT_IS(fret1->getRowType(1), rt2.get());
	UT_IS(fret1->getRowType(-1), NULL);
	UT_IS(fret1->getRowType(2), NULL);

	UT_IS(*(fret1->getLabelName(0)), "one");
	UT_IS(*(fret1->getLabelName(1)), "two");
	UT_IS(fret1->getLabelName(-1), NULL);
	UT_IS(fret1->getLabelName(2), NULL);

	UT_IS(fret1->getLabel("one")->getType(), rt1.get());
	UT_IS(fret1->getLabel("two")->getType(), rt2.get());
	UT_IS(fret1->getLabel("zzz"), NULL);

	UT_IS(fret1->getLabel(0)->getType(), rt1.get());
	UT_IS(fret1->getLabel(1)->getType(), rt2.get());
	UT_IS(fret1->getLabel(-1), NULL);
	UT_IS(fret1->getLabel(2), NULL);
}

