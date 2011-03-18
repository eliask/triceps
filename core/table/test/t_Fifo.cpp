//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of table creation with a fifo index.

#include <utest/Utest.h>
#include <string.h>

#include <type/AllTypes.h>
#include <common/StringUtil.h>
#include <table/Table.h>
#include <table/HashedIndex.h>
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

UTESTCASE fifoIndex(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = TableType::make(rt1)
		->addIndex("fifo", FifoIndexType::make()
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::SM_IGNORE, "t");
	UT_ASSERT(!t.isNull());
	UT_ASSERT(t->getInputLabel() != NULL);
	UT_ASSERT(t->getLabel() != NULL);
	UT_IS(t->getInputLabel()->getName(), "t.in");
	UT_IS(t->getLabel()->getName(), "t.out");

	// create a matrix of records

	RowHandle *iter;
	FdataVec dv;
	mkfdata(dv);

	int32_t one32 = 1, two32 = 2;
	int64_t one64 = 1, two64 = 2;

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&one64;
	Rowref r11(rt1,  rt1->makeRow(dv));
	Rhref rh11(t, t->makeRowHandle(r11));
	Rhref rh11copy(t, t->makeRowHandle(r11));

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
	UT_ASSERT(t->insert(rh11));
	UT_ASSERT(t->insert(rh12));
	UT_ASSERT(t->insert(rh21));
	UT_ASSERT(t->insert(rh22));

	// check the iteration in the same order
	iter = t->begin();
	UT_IS(iter, rh11);
	iter = t->next(iter);
	UT_IS(iter, rh12);
	iter = t->next(iter);
	UT_IS(iter, rh21);
	iter = t->next(iter);
	UT_IS(iter, rh22);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// do the finds
	iter = t->find(rh11);
	UT_IS(iter, rh11);
	iter = t->find(rh11copy);
	UT_IS(iter, rh11);

	iter = t->find(rh12);
	UT_IS(iter, rh12);
	iter = t->find(rh21);
	UT_IS(iter, rh21);
	iter = t->find(rh22);
	UT_IS(iter, rh22);

	// delete a record in the middle and check that the sequence got updated right
	t->remove(rh12);
	iter = t->next(rh11);
	UT_IS(iter, rh21);

	// next() on the removed row should return NULL
	iter = t->next(rh12);
	UT_IS(iter, NULL);

	// delete a record at the end
	t->remove(rh22);
	iter = t->next(rh21);
	UT_IS(iter, NULL);

	// delete a record at the front
	t->remove(rh11);
	iter = t->begin();
	UT_IS(iter, rh21);

	// delete the last record
	t->remove(rh21);
	iter = t->begin();
	UT_IS(iter, NULL);

	// insert a record back
	UT_ASSERT(t->insert(rh11));
	iter = t->begin();
	UT_IS(iter, rh11);
	iter = t->next(rh11);
	UT_IS(iter, NULL);

	// check that find() finds the first matching record
	UT_ASSERT(t->insert(rh11copy));
	iter = t->find(rh11copy);
	UT_IS(iter, rh11);
}

UTESTCASE fifoIndexLimit(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<Unit::StringNameTracer> trace = new Unit::StringNameTracer;
	unit->setTracer(trace);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addIndex("fifo", new FifoIndexType(2)
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::SM_CALL, "t");
	UT_ASSERT(!t.isNull());
	UT_ASSERT(t->getInputLabel() != NULL);
	UT_ASSERT(t->getLabel() != NULL);
	UT_IS(t->getInputLabel()->getName(), "t.in");
	UT_IS(t->getLabel()->getName(), "t.out");

	// create a matrix of records

	RowHandle *iter;
	FdataVec dv;
	mkfdata(dv);

	int32_t one32 = 1, two32 = 2;
	int64_t one64 = 1, two64 = 2;

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&one64;
	Rowref r11(rt1,  rt1->makeRow(dv));
	Rhref rh11(t, t->makeRowHandle(r11));
	Rhref rh11copy(t, t->makeRowHandle(r11));

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
	UT_ASSERT(t->insert(rh11));
	UT_ASSERT(t->insert(rh12));

	// check the iteration in the same order
	iter = t->begin();
	UT_IS(iter, rh11);
	iter = t->next(iter);
	UT_IS(iter, rh12);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// now insertion will be pushing out the previous records
	UT_ASSERT(t->insert(rh21));
	iter = t->begin();
	UT_IS(iter, rh12);

	UT_ASSERT(t->insert(rh22));

	// check the iteration in the same order
	iter = t->begin();
	UT_IS(iter, rh21);
	iter = t->next(iter);
	UT_IS(iter, rh22);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// check the trace
	unit->drainFrame();
	UT_ASSERT(unit->empty());
	string tlog = trace->getBuffer()->print();

	string expect = 
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
	;
	UT_IS(tlog, expect);
}

UTESTCASE fifoIndexJumping(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<Unit::StringNameTracer> trace = new Unit::StringNameTracer;
	unit->setTracer(trace);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addIndex("fifo", (new FifoIndexType())
			->setLimit(2)
			->setJumping(true)
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::SM_CALL, "t");
	UT_ASSERT(!t.isNull());
	UT_ASSERT(t->getInputLabel() != NULL);
	UT_ASSERT(t->getLabel() != NULL);
	UT_IS(t->getInputLabel()->getName(), "t.in");
	UT_IS(t->getLabel()->getName(), "t.out");

	// create a matrix of records

	RowHandle *iter;
	FdataVec dv;
	mkfdata(dv);

	int32_t one32 = 1, two32 = 2;
	int64_t one64 = 1, two64 = 2;

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&one64;
	Rowref r11(rt1,  rt1->makeRow(dv));
	Rhref rh11(t, t->makeRowHandle(r11));
	Rhref rh11copy(t, t->makeRowHandle(r11));

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
	UT_ASSERT(t->insert(rh11));
	UT_ASSERT(t->insert(rh12));

	// check the iteration in the same order
	iter = t->begin();
	UT_IS(iter, rh11);
	iter = t->next(iter);
	UT_IS(iter, rh12);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// now insertion will be pushing out all the previous records
	UT_ASSERT(t->insert(rh21));
	iter = t->begin();
	UT_IS(iter, rh21);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	UT_ASSERT(t->insert(rh22));

	// check the iteration in the same order
	iter = t->begin();
	UT_IS(iter, rh21);
	iter = t->next(iter);
	UT_IS(iter, rh22);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// check the trace
	unit->drainFrame();
	UT_ASSERT(unit->empty());
	string tlog = trace->getBuffer()->print();

	string expect = 
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op INSERT\n"
	;
	UT_IS(tlog, expect);
}

// check that if a record is already replaced by another index,
// fifo won't push out another record
UTESTCASE fifoIndexLimitReplace(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<Unit::StringNameTracer> trace = new Unit::StringNameTracer;
	unit->setTracer(trace);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = TableType::make(rt1)
		->addIndex("primary", HashedIndexType::make(
				NameSet::make()->add("b")->add("c")
			)
		)->addIndex("fifo", FifoIndexType::make(2)
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::SM_CALL, "t");
	UT_ASSERT(!t.isNull());
	UT_ASSERT(t->getInputLabel() != NULL);
	UT_ASSERT(t->getLabel() != NULL);
	UT_IS(t->getInputLabel()->getName(), "t.in");
	UT_IS(t->getLabel()->getName(), "t.out");

	IndexType *fifot = tt->findIndex("fifo");
	UT_ASSERT(fifot != NULL);

	// create a matrix of records

	RowHandle *iter;
	FdataVec dv;
	mkfdata(dv);

	int32_t one32 = 1, two32 = 2;
	int64_t one64 = 1, two64 = 2;

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&one64;
	Rowref r11(rt1,  rt1->makeRow(dv));
	Rhref rh11(t, t->makeRowHandle(r11));
	Rhref rh11copy(t, t->makeRowHandle(r11));

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&two64;
	Rowref r12(rt1,  rt1->makeRow(dv));
	Rhref rh12(t, t->makeRowHandle(r12));
	Rhref rh12copy(t, t->makeRowHandle(r12));

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
	UT_ASSERT(t->insert(rh11));
	UT_ASSERT(t->insert(rh12));

	// check the iteration in the same order
	UT_IS(t->size(), 2);
	iter = t->beginIdx(fifot);
	UT_IS(iter, rh11);
	iter = t->nextIdx(fifot, iter);
	UT_IS(iter, rh12);
	iter = t->nextIdx(fifot, iter);
	UT_IS(iter, NULL);

	// now replace the 2nd record according to the primary index
	UT_ASSERT(t->insert(rh12copy));

	// make sure that it didn't push anything else out
	UT_IS(t->size(), 2);
	iter = t->beginIdx(fifot);
	UT_IS(iter, rh11);
	iter = t->nextIdx(fifot, iter);
	UT_IS(iter, rh12copy);
	iter = t->nextIdx(fifot, iter);
	UT_IS(iter, NULL);

	// replace the 1st record
	UT_ASSERT(t->insert(rh11copy));

	// make sure that it didn't push anything else out and moved to the back
	UT_IS(t->size(), 2);
	iter = t->beginIdx(fifot);
	UT_IS(iter, rh12copy);
	iter = t->nextIdx(fifot, iter);
	UT_IS(iter, rh11copy);
	iter = t->nextIdx(fifot, iter);
	UT_IS(iter, NULL);

	// now insertion will be pushing out the previous records
	UT_ASSERT(t->insert(rh21));
	UT_IS(t->size(), 2);
	iter = t->beginIdx(fifot);
	UT_IS(iter, rh11copy);

	UT_ASSERT(t->insert(rh22));
	UT_IS(t->size(), 2);

	// check the trace
	unit->drainFrame();
	UT_ASSERT(unit->empty());
	string tlog = trace->getBuffer()->print();

	string expect = 
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
	;
	UT_IS(tlog, expect);
}

// check that if another index goes after fifo, fifo won't care
UTESTCASE fifoIndexLimitNoReplace(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<Unit::StringNameTracer> trace = new Unit::StringNameTracer;
	unit->setTracer(trace);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = (new TableType(rt1))
		->addIndex("fifo", new FifoIndexType(2)
		)->addIndex("primary", (new HashedIndexType(
			(new NameSet())->add("b")->add("c")
			))
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::SM_CALL, "t");
	UT_ASSERT(!t.isNull());
	UT_ASSERT(t->getInputLabel() != NULL);
	UT_ASSERT(t->getLabel() != NULL);
	UT_IS(t->getInputLabel()->getName(), "t.in");
	UT_IS(t->getLabel()->getName(), "t.out");

	// create a matrix of records

	RowHandle *iter;
	FdataVec dv;
	mkfdata(dv);

	int32_t one32 = 1;
	int64_t one64 = 1, two64 = 2;

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&one64;
	Rowref r11(rt1,  rt1->makeRow(dv));
	Rhref rh11(t, t->makeRowHandle(r11));
	Rhref rh11copy(t, t->makeRowHandle(r11));

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&two64;
	Rowref r12(rt1,  rt1->makeRow(dv));
	Rhref rh12(t, t->makeRowHandle(r12));
	Rhref rh12copy(t, t->makeRowHandle(r12));

	// so far the table must be empty
	iter = t->begin();
	UT_IS(iter, NULL);

	// basic insertion
	UT_ASSERT(t->insert(rh11));
	UT_ASSERT(t->insert(rh12));

	// check the iteration in the same order
	UT_IS(t->size(), 2);
	iter = t->begin();
	UT_IS(iter, rh11);
	iter = t->next(iter);
	UT_IS(iter, rh12);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// now replace the 2nd record according to the primary index
	UT_ASSERT(t->insert(rh12copy));

	// make sure that it pushed out according to both oilicies
	UT_IS(t->size(), 1);
	iter = t->begin();
	UT_IS(iter, rh12copy);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// restore the 1st record
	UT_ASSERT(t->insert(rh11copy));

	// make sure that it didn't push anything else out and moved to the back
	UT_IS(t->size(), 2);
	iter = t->begin();
	UT_IS(iter, rh12copy);
	iter = t->next(iter);
	UT_IS(iter, rh11copy);
	iter = t->next(iter);
	UT_IS(iter, NULL);

	// check the trace
	unit->drainFrame();
	UT_ASSERT(unit->empty());
	string tlog = trace->getBuffer()->print();

	string expect = 
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op DELETE\n"
		"unit 'u' before label 't.out' op INSERT\n"
		"unit 'u' before label 't.out' op INSERT\n"
	;
	UT_IS(tlog, expect);
}

// check iteration through a deeply nested index
UTESTCASE deepNested(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<Unit> unit = new Unit("u");
	Autoref<Unit::StringNameTracer> trace = new Unit::StringNameTracer;
	unit->setTracer(trace);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	UT_ASSERT(rt1->getErrors().isNull());

	Autoref<TableType> tt = TableType::make(rt1)
		->addIndex("parallel1", FifoIndexType::make()
		)->addIndex("level1", HashedIndexType::make(
				NameSet::make()->add("b")
			)->addNested("parallel2", FifoIndexType::make()
			)->addNested("level2", HashedIndexType::make(
					NameSet::make()->add("c")
				)->addNested("parallel3", FifoIndexType::make()
				)->addNested("level3", FifoIndexType::make()
				)
			)
		);

	UT_ASSERT(tt);
	tt->initialize();
	UT_ASSERT(tt->getErrors().isNull());
	UT_ASSERT(!tt->getErrors()->hasError());

	Autoref<Table> t = tt->makeTable(unit, Table::SM_CALL, "t");
	UT_ASSERT(!t.isNull());

	Autoref<IndexType> level3 = tt->findIndex("level1")->findNested("level2")->findNested("level3");
	UT_ASSERT(!level3.isNull());
	Autoref<IndexType> level2 = tt->findIndex("level1")->findNested("level2");
	UT_ASSERT(!level2.isNull());

	// create a matrix of records

	RowHandle *iter;
	FdataVec dv;
	mkfdata(dv);

	int32_t one32 = 1, two32 = 2;
	int64_t one64 = 1, two64 = 2;
	static char id[] = "x";

	dv[4].data_= id;

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&one64;
	id[0] = 'a';
	Rowref r11(rt1,  rt1->makeRow(dv));
	Rhref rh11(t, t->makeRowHandle(r11));
	id[0] = 'b';
	Rhref rh11copy(t, t->makeRowHandle(rt1->makeRow(dv)));

	dv[1].data_ = (char *)&one32; dv[2].data_ = (char *)&two64;
	id[0] = 'c';
	Rowref r12(rt1,  rt1->makeRow(dv));
	Rhref rh12(t, t->makeRowHandle(r12));
	id[0] = 'd';
	Rhref rh12copy(t, t->makeRowHandle(rt1->makeRow(dv)));

	dv[1].data_ = (char *)&two32; dv[2].data_ = (char *)&one64;
	id[0] = 'e';
	Rowref r21(rt1,  rt1->makeRow(dv));
	Rhref rh21(t, t->makeRowHandle(r21));
	id[0] = 'f';
	Rhref rh21copy(t, t->makeRowHandle(rt1->makeRow(dv)));

	dv[1].data_ = (char *)&two32; dv[2].data_ = (char *)&two64;
	id[0] = 'g';
	Rowref r22(rt1,  rt1->makeRow(dv));
	Rhref rh22(t, t->makeRowHandle(r22));
	id[0] = 'h';
	Rhref rh22copy(t, t->makeRowHandle(rt1->makeRow(dv)));

	// so far the table must be empty
	iter = t->beginIdx(level3);
	UT_IS(iter, NULL);

	// basic insertion
	UT_ASSERT(t->insert(rh11));
	UT_ASSERT(t->insert(rh12));
	UT_ASSERT(t->insert(rh21));
	UT_ASSERT(t->insert(rh22));
	UT_ASSERT(t->insert(rh11copy));
	UT_ASSERT(t->insert(rh12copy));
	UT_ASSERT(t->insert(rh21copy));
	UT_ASSERT(t->insert(rh22copy));

	string seq; // this is purely for entertainment, see the resulting order
	int bitmap = 0;
	int i = 0;
	
	// fprintf(stderr, "  loop begin\n"); 
	for (iter = t->beginIdx(level3); iter != NULL; iter = t->nextIdx(level3, iter)) {
		++i;
		const char *rid = rt1->getString(iter->getRow(), 4);
		// fprintf(stderr, "  loop %d: %c\n", i, rid[0]); 
		seq += rid;
		bitmap |= (1 << (rid[0] - 'a'));
	}
	UT_IS(bitmap, 0xFF);
	printf("    iteration order: %s\n", seq.c_str()); fflush(stdout);

	// now the same iteration on a nested index
	seq.clear();
	bitmap = 0;
	i = 0;
	
	// fprintf(stderr, "  loop2 begin\n"); 
	for (iter = t->beginIdx(level3); iter != NULL; iter = t->nextIdx(level3, iter)) {
		++i;
		const char *rid = rt1->getString(iter->getRow(), 4);
		// fprintf(stderr, "  loop2 %d: %c\n", i, rid[0]); 
		seq += rid;
		bitmap |= (1 << (rid[0] - 'a'));
	}
	UT_IS(bitmap, 0xFF);
	printf("    iteration order: %s\n", seq.c_str()); fflush(stdout);
}
