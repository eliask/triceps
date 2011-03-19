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

class TestGadget : public GadgetCE
{
public:
	// copy here the whole protected interface
	
	TestGadget(Unit *unit, EnqMode mode, const string &name, Onceref<RowType> rt) :
		GadgetCE(unit, mode, name, rt)
	{ }

	void setName(const string &name)
	{
		GadgetCE::setName(name);
	}

	void setRowType(Onceref<RowType> rt)
	{
		GadgetCE::setRowType(rt);
	}

	void send(const Row *row, Rowop::Opcode opcode, Tray *copyTray)
	{
		GadgetCE::send(row, opcode, copyTray);
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
	UT_IS(g1->getEnqMode(), Gadget::SM_IGNORE);
	UT_IS(g1->getLabel(), NULL);

	g1->setName("gg1");
	UT_IS(g1->getName(), "gg1");

	g1->setEnqMode(Gadget::SM_CALL);
	UT_IS(g1->getEnqMode(), Gadget::SM_CALL);

	g1->setRowType(rt1);
	UT_ASSERT(g1->getLabel() != NULL);
	UT_ASSERT(g1->getLabel()->getType() == rt1.get());
}

// this pretty much copies the t_Unit, only instead of scheduling the
// records directly, they go through gadgets

// for scheduling test, make gadgets that push rowops
// onto the queue in different ways.
class LabelTwoGadgets : public Label
{
public:
	LabelTwoGadgets(Unit *unit, Onceref<RowType> rtype, const string &name,
			Onceref<TestGadget> sub1, Onceref<TestGadget> sub2, 
			Onceref<Label> forcall, Onceref<Tray>tray) :
		Label(unit, rtype, name),
		sub1_(sub1),
		sub2_(sub2),
		forcall_(forcall),
		tray_(tray)
	{ }

	virtual void execute(Rowop *arg) const
	{
		sub1_->send(arg->getRow(), arg->getOpcode(), tray_);
		sub2_->send(arg->getRow(), arg->getOpcode(), tray_);
		unit_->call(new Rowop(forcall_, Rowop::OP_NOP, (Row *)NULL));
	}

	Autoref<TestGadget> sub1_, sub2_; // gadgets to trigger
	Autoref<Label> forcall_; // a label to call immediately
	Autoref<Tray> tray_; // a tray to collect the copy of gadgets results
};

// test all 4 kinds of scheduling
UTESTCASE scheduling(Utest *utest)
{
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

	Autoref<TestGadget> g1 = new TestGadget(unit, Gadget::SM_SCHEDULE, "g1", rt1);
	Autoref<TestGadget> g2 = new TestGadget(unit, Gadget::SM_SCHEDULE, "g2", rt1);

	Autoref<Label> lab2 = new DummyLabel(unit, rt1, "lab2");

	Autoref<LabelTwoGadgets> lab1 = new LabelTwoGadgets(unit, rt1, "lab1", g1, g2, lab2, (Tray *)NULL);

	Autoref<Rowop> op1 = new Rowop(lab1, Rowop::OP_INSERT, r1);
	Autoref<Rowop> op2 = new Rowop(lab1, Rowop::OP_DELETE, r1);

	// now run it
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	string tlog;
	tlog = trace->getBuffer()->print();

	string expect_sched = 
		"unit 'u' before label 'lab1' op INSERT\n"
		"unit 'u' before label 'lab2' op NOP\n"
		"unit 'u' before label 'lab1' op DELETE\n"
		"unit 'u' before label 'lab2' op NOP\n"

		"unit 'u' before label 'g1' op INSERT\n"
		"unit 'u' before label 'g2' op INSERT\n"

		"unit 'u' before label 'g1' op DELETE\n"
		"unit 'u' before label 'g2' op DELETE\n"
	;

	UT_IS(tlog, expect_sched);

	// change the mode to fork and repeat
	g1->setEnqMode(Gadget::SM_FORK);
	g2->setEnqMode(Gadget::SM_FORK);

	trace->clearBuffer();
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	tlog = trace->getBuffer()->print();

	string expect_fork = 
		"unit 'u' before label 'lab1' op INSERT\n"
		"unit 'u' before label 'lab2' op NOP\n"

		"unit 'u' before label 'g1' op INSERT\n"
		"unit 'u' before label 'g2' op INSERT\n"

		"unit 'u' before label 'lab1' op DELETE\n"
		"unit 'u' before label 'lab2' op NOP\n"

		"unit 'u' before label 'g1' op DELETE\n"
		"unit 'u' before label 'g2' op DELETE\n"
	;

	UT_IS(tlog, expect_fork);

	// change the mode to call and repeat
	g1->setEnqMode(Gadget::SM_CALL);
	g2->setEnqMode(Gadget::SM_CALL);

	trace->clearBuffer();
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	tlog = trace->getBuffer()->print();

	string expect_call = 
		"unit 'u' before label 'lab1' op INSERT\n"
		"unit 'u' before label 'g1' op INSERT\n"
		"unit 'u' before label 'g2' op INSERT\n"
		"unit 'u' before label 'lab2' op NOP\n"

		"unit 'u' before label 'lab1' op DELETE\n"
		"unit 'u' before label 'g1' op DELETE\n"
		"unit 'u' before label 'g2' op DELETE\n"
		"unit 'u' before label 'lab2' op NOP\n"
	;

	UT_IS(tlog, expect_call);

	// change the mode to ignore and repeat
	g1->setEnqMode(Gadget::SM_IGNORE);
	g2->setEnqMode(Gadget::SM_IGNORE);

	trace->clearBuffer();
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	tlog = trace->getBuffer()->print();

	string expect_ignore = 
		"unit 'u' before label 'lab1' op INSERT\n"
		"unit 'u' before label 'lab2' op NOP\n"

		"unit 'u' before label 'lab1' op DELETE\n"
		"unit 'u' before label 'lab2' op NOP\n"
	;

	UT_IS(tlog, expect_ignore);

	// Now test how all the same modes work with a copy tray.
	// The tray will be populated the same with every mode.
	Autoref<Tray> tray = new Tray;
	lab1->tray_ = tray;

	// do the schedule mode
	tray->clear();
	g1->setEnqMode(Gadget::SM_SCHEDULE);
	g2->setEnqMode(Gadget::SM_SCHEDULE);

	trace->clearBuffer();
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	tlog = trace->getBuffer()->print();

	UT_IS(tlog, expect_sched);
	if (UT_IS(tray->size(), 4)) return;
	UT_IS(tray->at(0)->getLabel(), g1->getLabel());
	UT_IS(tray->at(0)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(1)->getLabel(), g2->getLabel());
	UT_IS(tray->at(1)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(2)->getLabel(), g1->getLabel());
	UT_IS(tray->at(2)->getOpcode(), Rowop::OP_DELETE);
	UT_IS(tray->at(3)->getLabel(), g2->getLabel());
	UT_IS(tray->at(3)->getOpcode(), Rowop::OP_DELETE);

	// do the fork mode
	tray->clear();
	g1->setEnqMode(Gadget::SM_FORK);
	g2->setEnqMode(Gadget::SM_FORK);

	trace->clearBuffer();
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	tlog = trace->getBuffer()->print();

	UT_IS(tlog, expect_fork);
	if (UT_IS(tray->size(), 4)) return;
	UT_IS(tray->at(0)->getLabel(), g1->getLabel());
	UT_IS(tray->at(0)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(1)->getLabel(), g2->getLabel());
	UT_IS(tray->at(1)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(2)->getLabel(), g1->getLabel());
	UT_IS(tray->at(2)->getOpcode(), Rowop::OP_DELETE);
	UT_IS(tray->at(3)->getLabel(), g2->getLabel());
	UT_IS(tray->at(3)->getOpcode(), Rowop::OP_DELETE);

	// do the call mode
	tray->clear();
	g1->setEnqMode(Gadget::SM_CALL);
	g2->setEnqMode(Gadget::SM_CALL);

	trace->clearBuffer();
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	tlog = trace->getBuffer()->print();

	UT_IS(tlog, expect_call);
	if (UT_IS(tray->size(), 4)) return;
	UT_IS(tray->at(0)->getLabel(), g1->getLabel());
	UT_IS(tray->at(0)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(1)->getLabel(), g2->getLabel());
	UT_IS(tray->at(1)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(2)->getLabel(), g1->getLabel());
	UT_IS(tray->at(2)->getOpcode(), Rowop::OP_DELETE);
	UT_IS(tray->at(3)->getLabel(), g2->getLabel());
	UT_IS(tray->at(3)->getOpcode(), Rowop::OP_DELETE);

	// do the ignore mode
	tray->clear();
	g1->setEnqMode(Gadget::SM_IGNORE);
	g2->setEnqMode(Gadget::SM_IGNORE);

	trace->clearBuffer();
	unit->schedule(op1);
	unit->schedule(op2);
	unit->drainFrame();
	UT_ASSERT(unit->empty());

	tlog = trace->getBuffer()->print();

	UT_IS(tlog, expect_ignore);
	if (UT_IS(tray->size(), 4)) return;
	UT_IS(tray->at(0)->getLabel(), g1->getLabel());
	UT_IS(tray->at(0)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(1)->getLabel(), g2->getLabel());
	UT_IS(tray->at(1)->getOpcode(), Rowop::OP_INSERT);
	UT_IS(tray->at(2)->getLabel(), g1->getLabel());
	UT_IS(tray->at(2)->getOpcode(), Rowop::OP_DELETE);
	UT_IS(tray->at(3)->getLabel(), g2->getLabel());
	UT_IS(tray->at(3)->getOpcode(), Rowop::OP_DELETE);
}
