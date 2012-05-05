//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of aggregations.

#include <utest/Utest.h>
#include <string.h>

#include <type/AllTypes.h>
#include <common/StringUtil.h>
#include <table/Table.h>
#include <type/BasicAggregatorType.h>
#include <table/BasicAggregator.h>
#include <mem/Rhref.h>

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

uint8_t v_uint8[10] = "123456789";
int32_t v_int32 = 1234;
int64_t v_int64 = 0xdeadbeefc00c;
double v_float64 = 9.99e99;
char v_string[] = "hello world";

void mkfdata(FdataVec &fd)
{
	fd.resize(4);
	fd[0].setPtr(true, &v_uint8, sizeof(v_uint8));
	fd[1].setPtr(true, &v_int32, sizeof(v_int32));
	fd[2].setPtr(true, &v_int64, sizeof(v_int64));
	fd[3].setPtr(true, &v_float64, sizeof(v_float64));
	// test the constructor
	fd.push_back(Fdata(true, &v_string, sizeof(v_string)));
}

Onceref<TableType> mktabtype(Onceref<RowType> rt)
{
	return (new TableType(rt))
			->addSubIndex("primary", (new HashedIndexType(
				(new NameSet())->add("b")
				))->addSubIndex("level2", new HashedIndexType(
					(new NameSet())->add("c")
				)
			)
		);
}

// an "aggregator" that records the history of calls
Erref aggHistory(new Errors);
void recordHistory(Table *table, AggregatorGadget *gadget, Index *index,
        const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
		Aggregator::AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
{
	aggHistory->appendMsg(false, strprintf("%s ao=%s op=%s count=%d",
		gadget->getName().c_str(), Aggregator::aggOpString(aggop),
		Rowop::opcodeString(opcode), (int)parentIndexType->groupSize(gh)));

	// and also produce the output by sending the first record of the group!
	if (!Rowop::isNop(opcode)) {
		RowHandle *rh = index->begin();
		if (rh != NULL) {
			// this is an OK approach, sending nothing on empty groups,
			// it's an easy way to provide consistency
			gadget->sendDelayed(dest, rh->getRow(), opcode, copyTray);
		}
	}
}

// a label that counts the records that went through it
class CounterLabel : public Label
{
public:
	CounterLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name = "") :
		Label(unit, rtype, name),
		count_(0)
	{ }

	virtual void execute(Rowop *arg) const
	{
		++count_;
	}
	
	mutable int count_;
};

UTESTCASE stringConst(Utest *utest)
{
	UT_IS(Aggregator::aggOpString(Aggregator::AO_BEFORE_MOD), string("AO_BEFORE_MOD"));
	UT_IS(Aggregator::aggOpString(Aggregator::AO_AFTER_DELETE), string("AO_AFTER_DELETE"));
	UT_IS(Aggregator::aggOpString(Aggregator::AO_AFTER_INSERT), string("AO_AFTER_INSERT"));
	UT_IS(Aggregator::aggOpString(Aggregator::AO_COLLAPSE), string("AO_COLLAPSE"));
	UT_IS(Aggregator::aggOpString(999), string("???"));
	UT_IS(Aggregator::aggOpString(999, NULL), NULL);

	UT_IS(Aggregator::stringAggOp("AO_BEFORE_MOD"), Aggregator::AO_BEFORE_MOD);
	UT_IS(Aggregator::stringAggOp("AO_AFTER_DELETE"), Aggregator::AO_AFTER_DELETE);
	UT_IS(Aggregator::stringAggOp("AO_AFTER_INSERT"), Aggregator::AO_AFTER_INSERT);
	UT_IS(Aggregator::stringAggOp("AO_COLLAPSE"), Aggregator::AO_COLLAPSE);
	UT_IS(Aggregator::stringAggOp("xxx"), -1);
}

UTESTCASE badName(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	// Adds aggregators with names duplicating the embedded gadgets
	Autoref<TableType> tt = ( new TableType(rt1))
			->addSubIndex("primary", (new HashedIndexType(
				(new NameSet())->add("b")
				))->addSubIndex("level2", (new HashedIndexType(
						(new NameSet())->add("c")
					))->setAggregator(
						new BasicAggregatorType("in", rt1, recordHistory)
					)
				)->setAggregator(
					new BasicAggregatorType("out", rt1, recordHistory)
				)
			);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(!tt->getErrors().isNull());
	UT_ASSERT(tt->getErrors()->hasError());
	UT_IS(tt->getErrors()->print(), "duplicate aggregator/label name 'out'\nduplicate aggregator/label name 'in'\n");
}

UTESTCASE tableops(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<Unit::StringNameTracer> trace = new Unit::StringNameTracer;
	unit->setTracer(trace);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	// same as mktabtype but adds an aggregator to count collapses
	Autoref<TableType> tt = ( new TableType(rt1))
			->addSubIndex("primary", (new HashedIndexType(
				(new NameSet())->add("b")
				))->addSubIndex("level2", (new HashedIndexType(
						(new NameSet())->add("c")
					))->setAggregator(
						new BasicAggregatorType("onLevel2", rt1, recordHistory)
					)
				)->setAggregator(
					new BasicAggregatorType("onPrimary", rt1, recordHistory)
				)
			);

	aggHistory = new Errors;

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::EM_CALL, "t");
	UT_ASSERT(!t.isNull());

	IndexType *prim = tt->findSubIndex("primary");
	UT_ASSERT(prim != NULL);

	IndexType *sec = prim->findSubIndex("level2");
	UT_ASSERT(sec != NULL);

	// above here was a copy of primaryIndex(), with aggregators added
	
	// add the labels for processing of aggregator results
	Autoref<CounterLabel> countLevel2 = new CounterLabel(unit, rt1, "countLevel2");
	Autoref<CounterLabel> countPrimary = new CounterLabel(unit, rt1, "countPrimary");

	Label *al;

	al = t->getAggregatorLabel("onLevel2");
	UT_ASSERT(al != NULL);
	al->chain(countLevel2);

	al = t->getAggregatorLabel("onPrimary");
	UT_ASSERT(al != NULL);
	al->chain(countPrimary);

	al = t->getAggregatorLabel("noSuch");
	UT_ASSERT(al == NULL);

	// create a matrix of records, across both axes of indexing

	RowHandle *iter, *iter2;
	Fdata v1, v2;
	int i;
	FdataVec dv;
	mkfdata(dv);

	int32_t one32 = 1, two32 = 2;
	int64_t one64 = 1, two64 = 2;

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&one64;
	Rowref r11(rt1,  rt1->makeRow(dv));
	Rhref rh11(t, t->makeRowHandle(r11));

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&two64;
	Rowref r12(rt1,  rt1->makeRow(dv));
	Rhref rh12(t, t->makeRowHandle(r12));

	dv[1].data_ = (char *)&two32; dv[2].data_ = (char *)&one64;
	Rowref r21(rt1,  rt1->makeRow(dv));
	Rhref rh21(t, t->makeRowHandle(r21));

	dv[1].data_ = (char *)&two32; dv[2].data_ = (char *)&two64;
	Rowref r22(rt1,  rt1->makeRow(dv));
	Rhref rh22(t, t->makeRowHandle(r22));

	// so far the table must be empty
	iter = t->begin();
	UT_IS(iter, NULL);

	// basic insertion
	aggHistory->appendMsg(false, "+insert 11");
	UT_ASSERT(t->insert(rh11));
	aggHistory->appendMsg(false, "+insert 22");
	UT_ASSERT(t->insert(rh22));
	aggHistory->appendMsg(false, "+insert 12");
	UT_ASSERT(t->insert(rh12));
	aggHistory->appendMsg(false, "+insert 21");
	UT_ASSERT(t->insert(rh21));

	// see that they can be found by index
	iter = t->findIdx(sec, rh11);
	UT_IS(iter, rh11);
	iter = t->findIdx(sec, rh12);
	UT_IS(iter, rh12);
	iter = t->findIdx(sec, rh21);
	UT_IS(iter, rh21);
	iter = t->findIdx(sec, rh22);
	UT_IS(iter, rh22);

	// now must have 4 records, grouped by field b
	iter = t->begin();
	UT_ASSERT(iter != NULL);
	iter2 = t->next(iter);
	UT_ASSERT(iter2 != NULL);

		// check the grouping
		v1.setFrom(rt1, iter->getRow(), 1);
		v2.setFrom(rt1, iter2->getRow(), 1);
		UT_ASSERT(!memcmp(v1.data_, v2.data_, sizeof(int32_t)));

	iter = t->next(iter2);
	UT_ASSERT(iter != NULL);
	iter2 = t->next(iter);
	UT_ASSERT(iter2 != NULL);

		// check the grouping
		v1.setFrom(rt1, iter->getRow(), 1);
		v2.setFrom(rt1, iter2->getRow(), 1);
		UT_ASSERT(!memcmp(v1.data_, v2.data_, sizeof(int32_t)));

	iter = t->next(iter2);
	UT_IS(iter, NULL);

	// this should replace the row with an identical one but with auto-created handle
	aggHistory->appendMsg(false, "+replace 11");
	UT_ASSERT(t->insertRow(r11));
	// check that the old record is not in the table any more
	i = 0;
	iter2 = NULL;
	for (iter = t->begin(); iter != NULL; iter = t->next(iter)) {
		++i;
		UT_ASSERT(iter != rh11);

		// remember the record with the macthing key
		v1.setFrom(rt1, iter->getRow(), 1);
		v2.setFrom(rt1, iter->getRow(), 2);
		if (!memcmp(v1.data_, &one32, sizeof(int32_t)) 
		&& !memcmp(v2.data_, &one64, sizeof(int64_t)) )
			iter2 = iter;
	}
	UT_IS(i, 4);

	// check that the newly inserted record can be found by find on the same key
	iter = t->findIdx(sec, rh11);
	UT_IS(iter, iter2);

	// check that iteration with NULL doesn't crash
	UT_ASSERT(t->next(NULL) == NULL);

	// and remove the remembered copy
	aggHistory->appendMsg(false, "+remove 11");
	t->remove(iter2);

	// check that the record is not there any more
	iter = t->findIdx(sec, rh11);
	UT_ASSERT(iter == NULL);

	// check that now have 3 records
	i = 0;
	for (iter = t->begin(); iter != NULL; iter = t->next(iter)) {
		++i;
	}
	UT_IS(i, 3);

	// remove the 2nd record from the same group, collapsing it
	aggHistory->appendMsg(false, "+remove 12");
	t->remove(rh12);
	
	// check that now have 2 records
	i = 0;
	for (iter = t->begin(); iter != NULL; iter = t->next(iter)) {
		++i;
	}
	UT_IS(i, 2);

	// now check the history collected by the aggregators
	const char *expect = 
		"+insert 11\n"
		"t.onPrimary ao=AO_AFTER_INSERT op=OP_INSERT count=1\n"
		"t.onLevel2 ao=AO_AFTER_INSERT op=OP_INSERT count=1\n"
		"+insert 22\n"
		"t.onPrimary ao=AO_BEFORE_MOD op=OP_DELETE count=1\n"
		"t.onPrimary ao=AO_AFTER_INSERT op=OP_INSERT count=2\n"
		"t.onLevel2 ao=AO_AFTER_INSERT op=OP_INSERT count=1\n"
		"+insert 12\n"
		"t.onPrimary ao=AO_BEFORE_MOD op=OP_DELETE count=2\n"
		"t.onLevel2 ao=AO_BEFORE_MOD op=OP_DELETE count=1\n"
		"t.onPrimary ao=AO_AFTER_INSERT op=OP_INSERT count=3\n"
		"t.onLevel2 ao=AO_AFTER_INSERT op=OP_INSERT count=2\n"
		"+insert 21\n"
		"t.onPrimary ao=AO_BEFORE_MOD op=OP_DELETE count=3\n"
		"t.onLevel2 ao=AO_BEFORE_MOD op=OP_DELETE count=1\n"
		"t.onPrimary ao=AO_AFTER_INSERT op=OP_INSERT count=4\n"
		"t.onLevel2 ao=AO_AFTER_INSERT op=OP_INSERT count=2\n"
		"+replace 11\n"
		"t.onPrimary ao=AO_BEFORE_MOD op=OP_DELETE count=4\n"
		"t.onLevel2 ao=AO_BEFORE_MOD op=OP_DELETE count=2\n"
		"t.onPrimary ao=AO_AFTER_DELETE op=OP_NOP count=4\n"
		"t.onLevel2 ao=AO_AFTER_DELETE op=OP_NOP count=2\n"
		"t.onPrimary ao=AO_AFTER_INSERT op=OP_INSERT count=4\n"
		"t.onLevel2 ao=AO_AFTER_INSERT op=OP_INSERT count=2\n"
		"+remove 11\n"
		"t.onPrimary ao=AO_BEFORE_MOD op=OP_DELETE count=4\n"
		"t.onLevel2 ao=AO_BEFORE_MOD op=OP_DELETE count=2\n"
		"t.onPrimary ao=AO_AFTER_DELETE op=OP_INSERT count=3\n"
		"t.onLevel2 ao=AO_AFTER_DELETE op=OP_INSERT count=1\n"
		"+remove 12\n"
		"t.onPrimary ao=AO_BEFORE_MOD op=OP_DELETE count=3\n"
		"t.onLevel2 ao=AO_BEFORE_MOD op=OP_DELETE count=1\n"
		"t.onPrimary ao=AO_AFTER_DELETE op=OP_INSERT count=2\n"
		"t.onLevel2 ao=AO_AFTER_DELETE op=OP_INSERT count=0\n"
		"t.onLevel2 ao=AO_COLLAPSE op=OP_NOP count=0\n"
	;
	string hist = aggHistory->print();
	UT_IS(hist, expect);

	// and the history collected by tracer
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	UT_IS(countLevel2->count_, 11);
	UT_IS(countPrimary->count_, 13);

	string tlog = trace->getBuffer()->print();

	string trace_expect = 
		"unit 'u' before label 't.out' op OP_INSERT\n"
		"unit 'u' before label 't.onPrimary' op OP_INSERT\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_INSERT\n"
		"unit 'u' before label 't.onLevel2' op OP_INSERT\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_INSERT\n"

		"unit 'u' before label 't.onPrimary' op OP_DELETE\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_DELETE\n"
		"unit 'u' before label 't.out' op OP_INSERT\n"
		"unit 'u' before label 't.onPrimary' op OP_INSERT\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_INSERT\n"
		"unit 'u' before label 't.onLevel2' op OP_INSERT\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_INSERT\n"

		"unit 'u' before label 't.onPrimary' op OP_DELETE\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_DELETE\n"
		"unit 'u' before label 't.onLevel2' op OP_DELETE\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_DELETE\n"
		"unit 'u' before label 't.out' op OP_INSERT\n"
		"unit 'u' before label 't.onPrimary' op OP_INSERT\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_INSERT\n"
		"unit 'u' before label 't.onLevel2' op OP_INSERT\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_INSERT\n"

		"unit 'u' before label 't.onPrimary' op OP_DELETE\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_DELETE\n"
		"unit 'u' before label 't.onLevel2' op OP_DELETE\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_DELETE\n"
		"unit 'u' before label 't.out' op OP_INSERT\n"
		"unit 'u' before label 't.onPrimary' op OP_INSERT\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_INSERT\n"
		"unit 'u' before label 't.onLevel2' op OP_INSERT\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_INSERT\n"

		"unit 'u' before label 't.onPrimary' op OP_DELETE\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_DELETE\n"
		"unit 'u' before label 't.onLevel2' op OP_DELETE\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_DELETE\n"
		"unit 'u' before label 't.out' op OP_DELETE\n"
		"unit 'u' before label 't.out' op OP_INSERT\n"
		"unit 'u' before label 't.onPrimary' op OP_INSERT\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_INSERT\n"
		"unit 'u' before label 't.onLevel2' op OP_INSERT\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_INSERT\n"

		"unit 'u' before label 't.onPrimary' op OP_DELETE\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_DELETE\n"
		"unit 'u' before label 't.onLevel2' op OP_DELETE\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_DELETE\n"
		"unit 'u' before label 't.out' op OP_DELETE\n"
		"unit 'u' before label 't.onPrimary' op OP_INSERT\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_INSERT\n"
		"unit 'u' before label 't.onLevel2' op OP_INSERT\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_INSERT\n"

		"unit 'u' before label 't.onPrimary' op OP_DELETE\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_DELETE\n"
		"unit 'u' before label 't.onLevel2' op OP_DELETE\n"
		"unit 'u' before label 'countLevel2' (chain 't.onLevel2') op OP_DELETE\n"
		"unit 'u' before label 't.out' op OP_DELETE\n"
		"unit 'u' before label 't.onPrimary' op OP_INSERT\n"
		"unit 'u' before label 'countPrimary' (chain 't.onPrimary') op OP_INSERT\n"
	;
	if (UT_IS(tlog, trace_expect)) {
		printf("expected: \"%s\"\n", trace_expect.c_str());
	}

}

// begin() implementation is common with the iteration on the table,
// but last() is unique to the aggregator interface, and needs to be tested
// for all index types.

// An aggregator that gets the last record and
// records its information in the messages
// (uses the same aggHistory as recordHistory()),
// sending nothing.
void recordLast(Table *table, AggregatorGadget *gadget, Index *index,
        const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
		Aggregator::AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
{
	int val_b = 9999;
	const char *val_e = "(none)";

	// pick fields e and b as "interesting" ones
	RowHandle *lastrh = index->last();
	if (lastrh != NULL) {
		val_e = table->getRowType()->getString(lastrh->getRow(), 4); // field e
		val_b = table->getRowType()->getInt32(lastrh->getRow(), 1, 0); // field b
	}

	aggHistory->appendMsg(false, strprintf("%s ao=%s op=%s e=%s b=%d",
		gadget->getName().c_str(), Aggregator::aggOpString(aggop),
		Rowop::opcodeString(opcode), val_e, val_b));
}

UTESTCASE aggLast(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	// there is no need for a primary index, put the aggregation
	// index(es) as top-level
	Autoref<TableType> tt = ( new TableType(rt1))
			->addSubIndex("Hashed", (new HashedIndexType( // will be the default index
					(new NameSet())->add("e")
				))->setAggregator(
					new BasicAggregatorType("onHashed", rt1, recordLast)
				)
			)->addSubIndex("Fifo", (new FifoIndexType(
				))->setAggregator(
					new BasicAggregatorType("onFifo", rt1, recordLast)
				)
			)->addSubIndex("HashedNested", (new HashedIndexType(
					(new NameSet())->add("e")
				))->addSubIndex("innerFifo", new FifoIndexType() 
					// will always contain one row per fifo because "Hashed" will force it
				)->setAggregator(
					new BasicAggregatorType("onHashedNested", rt1, recordLast)
				)
			);

	aggHistory = new Errors;

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::EM_CALL, "t");
	UT_ASSERT(!t.isNull());

	FdataVec dv;
	mkfdata(dv);

	char sval[2] = "x"; // one-character string for "e"
	dv[4].setPtr(true, &sval, sizeof(sval));

	Rowref r11(rt1);

	sval[0] = 'A';
	r11 = rt1->makeRow(dv);
	UT_ASSERT(t->insertRow(r11));
	
	sval[0] = 'B';
	r11 = rt1->makeRow(dv);
	UT_ASSERT(t->insertRow(r11));
	
	sval[0] = 'C';
	r11 = rt1->makeRow(dv);
	UT_ASSERT(t->insertRow(r11));
	
	sval[0] = 'D';
	r11 = rt1->makeRow(dv);
	UT_ASSERT(t->insertRow(r11));
	
	sval[0] = 'A';
	r11 = rt1->makeRow(dv);
	UT_ASSERT(t->deleteRow(r11));
	
	// this will be a replacement
	sval[0] = 'B';
	r11 = rt1->makeRow(dv);
	UT_ASSERT(t->insertRow(r11));
	
	// XXX this result depends on ordering of records in hash
	string result_expect = 
		"t.onHashed ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onFifo ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onHashedNested ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onHashed ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onFifo ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onHashedNested ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onHashed ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onFifo ao=AO_AFTER_INSERT op=OP_INSERT e=B b=1234\n"
		"t.onHashedNested ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onHashed ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onFifo ao=AO_BEFORE_MOD op=OP_DELETE e=B b=1234\n"
		"t.onHashedNested ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onHashed ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onFifo ao=AO_AFTER_INSERT op=OP_INSERT e=C b=1234\n"
		"t.onHashedNested ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onHashed ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onFifo ao=AO_BEFORE_MOD op=OP_DELETE e=C b=1234\n"
		"t.onHashedNested ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onHashed ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onFifo ao=AO_AFTER_INSERT op=OP_INSERT e=D b=1234\n"
		"t.onHashedNested ao=AO_AFTER_INSERT op=OP_INSERT e=A b=1234\n"
		"t.onHashed ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onFifo ao=AO_BEFORE_MOD op=OP_DELETE e=D b=1234\n"
		"t.onHashedNested ao=AO_BEFORE_MOD op=OP_DELETE e=A b=1234\n"
		"t.onHashed ao=AO_AFTER_DELETE op=OP_INSERT e=D b=1234\n"
		"t.onFifo ao=AO_AFTER_DELETE op=OP_INSERT e=D b=1234\n"
		"t.onHashedNested ao=AO_AFTER_DELETE op=OP_INSERT e=D b=1234\n"
		"t.onHashed ao=AO_BEFORE_MOD op=OP_DELETE e=D b=1234\n"
		"t.onFifo ao=AO_BEFORE_MOD op=OP_DELETE e=D b=1234\n"
		"t.onHashedNested ao=AO_BEFORE_MOD op=OP_DELETE e=D b=1234\n"
		"t.onHashed ao=AO_AFTER_DELETE op=OP_NOP e=D b=1234\n"
		"t.onFifo ao=AO_AFTER_DELETE op=OP_NOP e=B b=1234\n"
		"t.onHashedNested ao=AO_AFTER_DELETE op=OP_NOP e=D b=1234\n"
		"t.onHashed ao=AO_AFTER_INSERT op=OP_INSERT e=D b=1234\n"
		"t.onFifo ao=AO_AFTER_INSERT op=OP_INSERT e=B b=1234\n"
		"t.onHashedNested ao=AO_AFTER_INSERT op=OP_INSERT e=D b=1234\n"
	;
	string tlog = aggHistory->print();
	UT_IS(tlog, result_expect);
}

