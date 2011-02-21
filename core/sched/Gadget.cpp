//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A basic stateful element inside a Unit.

#include <sched/Gadget.h>

namespace BICEPS_NS {

Gadget::Gadget(Unit *unit, SchedMode mode, const string &name, Onceref<RowType> rt) :
	unit_(unit),
	name_(name),
	mode_(mode)
{
	assert(unit);
	if (!rt.isNull())
		setRowType(rt);
}

Gadget::~Gadget()
{ }

void Gadget::setRowType(Onceref<RowType> rt)
{
	type_ = rt;
	if (!rt.isNull()) {
		label_ = new DummyLabel(unit_, type_, name_);
	}
}

void Gadget::send(Row *row, Rowop::Opcode opcode, Tray *copyTray, Label *copyLabel)
{
	assert(!label_.isNull());

	if (row == NULL)
		return; // nothing to do

	if (mode_ != SM_IGNORE) {
		Autoref<Rowop> rop = new Rowop(label_, opcode, row);
		switch(mode_) {
		case SM_SCHEDULE:
			unit_->schedule(rop);
			break;
		case SM_FORK:
			unit_->fork(rop);
			break;
		case SM_CALL:
			unit_->call(rop);
			break;
		default:
			break; // shut up the compiler
		}
	}

	if (copyTray != NULL) {
		assert(copyLabel != NULL);
		copyTray->push_back(new Rowop(copyLabel, opcode, row));
	}
}

}; // BICEPS_NS
