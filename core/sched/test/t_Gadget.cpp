//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of Unit gadget base class.

#include <utest/Utest.h>
#include <string.h>

#include <type/CompactRowType.h>
#include <common/StringUtil.h>
#include <sched/Gadget.h>

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

class TestGadget : public Starget, public GadgetCS
{
public:
	// copy here the whole protected interface
	
	TestGadget(Unit *unit, SchedMode mode, const string &name, Onceref<RowType> rt) :
		GadgetCS(unit, mode, name, rt)
	{ }

	void setName(const string &name)
	{
		GadgetCS::setName(name);
	}

	void setRowType(Onceref<RowType> rt)
	{
		GadgetCS::setRowType(rt);
	}

	void send(Row *row, Rowop::Opcode opcode, Tray *copyTray, Label *copyLabel)
	{
		GadgetCS::send(row, opcode, copyTray, copyLabel);
	}
};

UTESTCASE mkgadget(Utest *utest)
{
	RowType::FieldVec fld;
	mkfields(fld);

	Autoref<RowType> rt1 = new CompactRowType(fld);
	if (UT_ASSERT(rt1->getErrors().isNull())) return;

	Autoref<Unit> unit1 = new Unit("u");

	Autoref<TestGadget> g1 = new TestGadget(unit1, Gadget::SM_IGNORE, "g1", (RowType *)NULL);
	UT_IS(g1->getUnit(), unit1);
	UT_IS(g1->getName(), "g1");
	UT_IS(g1->getSchedMode(), Gadget::SM_IGNORE);
	UT_IS(g1->getSchedLabel(), NULL);

	g1->setName("gg1");
	UT_IS(g1->getName(), "gg1");

	g1->setSchedMode(Gadget::SM_CALL);
	UT_IS(g1->getSchedMode(), Gadget::SM_CALL);

	g1->setRowType(rt1);
	UT_ASSERT(g1->getSchedLabel() != NULL);
	UT_ASSERT(g1->getSchedLabel()->getType() == rt1.get());
}

// this pretty much copies the t_Unit, only instead of scheduling the
// records directly, they go through gadgets

// for scheduling test, make labels that push more labels
// onto the queue in different ways.
class LabelTwoGadgets : public Label
{
public:
	LabelTwoGadgets(Unit *unit, Onceref<RowType> rtype, const string &name,
			Onceref<TestGadget> sub1, Onceref<TestGadget> sub2) :
		Label(unit, rtype, name),
		sub1_(sub1),
		sub2_(sub2)
	{ }

	virtual void execute(Rowop *arg) const
	{
		sub1_->send(arg->getRow(), arg->getOpcode(), NULL, NULL);
		sub2_->send(arg->getRow(), arg->getOpcode(), NULL, NULL);
	}

	Autoref<TestGadget> sub1_, sub2_;
};

class LabelTwoGadgetsTray : public Label
{
public:
	LabelTwoGadgetsTray(Unit *unit, Onceref<RowType> rtype, const string &name,
			Onceref<TestGadget> sub1, Onceref<TestGadget> sub2, Onceref<Label> immed) :
		Label(unit, rtype, name),
		sub1_(sub1),
		sub2_(sub2),
		immed_(immed)
	{ }

	virtual void execute(Rowop *arg) const
	{
		Autoref<Tray> tr = new Tray;
		sub1_->send(arg->getRow(), arg->getOpcode(), tr, immed_);
		sub2_->send(arg->getRow(), arg->getOpcode(), tr, immed_);
		unit_->callTray(tr);
	}

	Autoref<TestGadget> sub1_, sub2_;
	Autoref<Label> immed_;
};
// test all 4 kinds of scheduling
UTESTCASE scheduling(Utest *utest)
{
	return;

#if 0 // {
	// make a unit 
	Autoref<Unit> unit = new Unit("u");
	Autoref<Unit::StringNameTracer> trace = new Unit::StringNameTracer;
	unit->setTracer(trace);

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

	Autoref<Label> lab4 = new LabelSchedForkCall(unit, rt1, "lab4", lab1, lab2, lab3, r1);
	Autoref<Label> lab5 = new LabelSchedForkCall(unit, rt1, "lab5", lab1, lab2, lab3, r1);

	Autoref<Rowop> op4 = new Rowop(lab4, Rowop::OP_NOP, NULL);
	Autoref<Rowop> op5 = new Rowop(lab5, Rowop::OP_NOP, NULL);

	unit->schedule(op4);
	unit->schedule(op5);
	UT_ASSERT(!unit->empty());

	// now run it
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	string tlog;
	tlog = trace->getBuffer()->print();

	string expect_sched = 
		"unit 'u' before label 'lab4' op NOP\n"
		"unit 'u' before label 'lab3' op INSERT\n"
		"unit 'u' before label 'lab3' op DELETE\n"
		"unit 'u' before label 'lab2' op INSERT\n"
		"unit 'u' before label 'lab2' op DELETE\n"

		"unit 'u' before label 'lab5' op NOP\n"
		"unit 'u' before label 'lab3' op INSERT\n"
		"unit 'u' before label 'lab3' op DELETE\n"
		"unit 'u' before label 'lab2' op INSERT\n"
		"unit 'u' before label 'lab2' op DELETE\n"

		"unit 'u' before label 'lab1' op INSERT\n"
		"unit 'u' before label 'lab1' op DELETE\n"
		"unit 'u' before label 'lab1' op INSERT\n"
		"unit 'u' before label 'lab1' op DELETE\n"
	;

	UT_IS(tlog, expect_sched);

#endif // }
}
