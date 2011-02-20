//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of Unit scheduling and components.

#include <utest/Utest.h>
#include <string.h>

#include <type/CompactRowType.h>
#include <common/StringUtil.h>
#include <sched/Unit.h>

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

UTESTCASE mkunit(Utest *utest)
{
	Autoref<Unit> unit1 = new Unit("my unit");
	UT_IS(unit1->getName(), "my unit");
	
	unit1->setName("xxx");
	UT_IS(unit1->getName(), "xxx");

	Autoref<Unit> unit2 = new Unit;
	UT_IS(unit2->getName(), "");

	// try setting a tracer
	Autoref<Unit::Tracer> tracer1 = new Unit::StringNameTracer;
	UT_IS(unit1->getTracer().get(), NULL);
	unit1->setTracer(tracer1);
	UT_IS(unit1->getTracer().get(), tracer1.get());

	UT_ASSERT(unit1->empty());
}

UTESTCASE mklabel(Utest *utest)
{
	// make row types for labels
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	if (UT_ASSERT(rt1->getErrors().isNull())) return;

	// rt2 is equal to rt1
	Autoref<RowType> rt2 = new CompactRowType(fld);
	if (UT_ASSERT(rt2->getErrors().isNull())) return;

	// rt3 is matching to rt1
	fld[0].name_ = "field1";
	Autoref<RowType> rt3 = new CompactRowType(fld);
	if (UT_ASSERT(rt3->getErrors().isNull())) return;
	
	// rt4 is outright different
	fld[0].type_ = Type::r_float64;
	Autoref<RowType> rt4 = new CompactRowType(fld);
	if (UT_ASSERT(rt4->getErrors().isNull())) return;

	Autoref<Unit> unit1 = new Unit("unit1");
	
	Autoref<Label> lab1 = new DummyLabel(unit1, rt1, "lab1");
	Autoref<Label> lab2 = new DummyLabel(unit1, rt2, "lab2");
	Autoref<Label> lab3 = new DummyLabel(unit1, rt3, "lab3");
	Autoref<Label> lab4 = new DummyLabel(unit1, rt4, "lab4");

	Autoref<Label> lab11 = new DummyLabel(unit1, rt1, "lab11");
	Autoref<Label> lab12 = new DummyLabel(unit1, rt1, "lab12");

	UT_IS(lab1->getType(), rt1.get());
	UT_IS(lab2->getType(), rt2.get());
	UT_IS(lab3->getType(), rt3.get());
	UT_IS(lab4->getType(), rt4.get());

	UT_ASSERT(lab1->chain(lab2));
	UT_ASSERT(!lab1->chain(lab3)); // matching but not equal types not allowed
	UT_ASSERT(!lab1->chain(lab4));

	// this is more of a reminder that when the loop detection
	// is added, the test needs to be altered too
	UT_ASSERT(lab2->chain(lab1)); // this creates a circular chain

	UT_IS(lab1->getChain().size(), 1);
	UT_ASSERT(lab1->getChain()[0] == lab2);
	
	lab1->clearChained(); // undoes the endless loop
	UT_IS(lab1->getChain().size(), 0);
	UT_ASSERT(lab1->chain(lab11));
	UT_ASSERT(lab1->chain(lab12));
	UT_IS(lab1->getChain().size(), 2);
	UT_ASSERT(lab1->getChain()[0] == lab11);
	UT_ASSERT(lab1->getChain()[1] == lab12);

	// play with names
	UT_IS(lab1->getName(), "lab1");
	lab1->setName("zzz");
	UT_IS(lab1->getName(), "zzz");
}

UTESTCASE rowop(Utest *utest)
{
	// make a unit 
	Autoref<Unit> unit = new Unit("my unit");

	// make row for setting
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	if (UT_ASSERT(rt1->getErrors().isNull())) return;

	FdataVec dv;
	mkfdata(dv);
	Rowref r1(rt1,  rt1->makeRow(dv));

	if (UT_ASSERT(!r1.isNull())) return;

	// make a few labels
	Autoref<Label> lab1 = new DummyLabel(unit, rt1, "lab1");
	Autoref<Label> lab2 = new DummyLabel(unit, rt1, "lab2");
	Autoref<Label> lab3 = new DummyLabel(unit, rt1, "lab3");

	// now make the rowops
	Autoref<Rowop> op1 = new Rowop(lab1, Rowop::OP_NOP, NULL);
	UT_ASSERT(!op1.isNull()); // make the compiler shut up about unused vars
	Autoref<Rowop> op2 = new Rowop(lab2, Rowop::OP_INSERT, rt1->makeRow(dv));
	UT_ASSERT(!op2.isNull()); // make the compiler shut up about unused vars
	Autoref<Rowop> op3 = new Rowop(lab3, Rowop::OP_DELETE, r1);
	UT_ASSERT(!op3.isNull()); // make the compiler shut up about unused vars

	// the opcode translation
	UT_ASSERT(!Rowop::isInsert(Rowop::OP_NOP));
	UT_ASSERT(!Rowop::isDelete(Rowop::OP_NOP));
	UT_ASSERT(Rowop::isInsert(Rowop::OP_INSERT));
	UT_ASSERT(!Rowop::isDelete(Rowop::OP_INSERT));
	UT_ASSERT(!Rowop::isInsert(Rowop::OP_DELETE));
	UT_ASSERT(Rowop::isDelete(Rowop::OP_DELETE));
	UT_ASSERT(Rowop::isInsert((Rowop::Opcode)0x333));
	UT_ASSERT(Rowop::isDelete((Rowop::Opcode)0x333));
	UT_ASSERT(!Rowop::isInsert((Rowop::Opcode)0x330));
	UT_ASSERT(!Rowop::isDelete((Rowop::Opcode)0x330));

	UT_ASSERT(!op1->isInsert());
	UT_ASSERT(!op1->isDelete());
	UT_ASSERT(op2->isInsert());
	UT_ASSERT(!op2->isDelete());
	UT_ASSERT(!op3->isInsert());
	UT_ASSERT(op3->isDelete());

	UT_IS(string(Rowop::opcodeString(Rowop::OP_NOP)), "NOP");
	UT_IS(string(Rowop::opcodeString(Rowop::OP_INSERT)), "INSERT");
	UT_IS(string(Rowop::opcodeString(Rowop::OP_DELETE)), "DELETE");
	UT_IS(string(Rowop::opcodeString((Rowop::Opcode)0x330)), "[NOP]");
	UT_IS(string(Rowop::opcodeString((Rowop::Opcode)0x331)), "[I]");
	UT_IS(string(Rowop::opcodeString((Rowop::Opcode)0x332)), "[D]");
	UT_IS(string(Rowop::opcodeString((Rowop::Opcode)0x333)), "[ID]");

	// getting back the components
	UT_IS(op1->getOpcode(), Rowop::OP_NOP);
	UT_IS(op2->getOpcode(), Rowop::OP_INSERT);
	UT_IS(op3->getOpcode(), Rowop::OP_DELETE);

	UT_IS(op1->getLabel(), lab1.get());
	UT_IS(op2->getLabel(), lab2.get());
	UT_IS(op3->getLabel(), lab3.get());

	UT_IS(op1->getRow(), NULL);
	UT_ASSERT(op2->getRow() != NULL);
	UT_IS(op3->getRow(), r1.get());
}

