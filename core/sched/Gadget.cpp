//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A basic stateful element inside a Unit.

#include <sched/Gadget.h>

namespace BICEPS_NS {

Gadget::Gadget(Unit *unit, EnqMode mode, const string &name, const_Onceref<RowType> rt) :
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

void Gadget::setRowType(const_Onceref<RowType> rt)
{
	type_ = rt;
	if (!rt.isNull()) {
		label_ = new DummyLabel(unit_, type_, name_);
	}
}

void Gadget::send(const Row *row, Rowop::Opcode opcode, Tray *copyTray) const
{
	// fprintf(stderr, "DEBUG Gadget::send(row=%p, opcode=0x%x, tray=%p) mode=%d\n", row, opcode, copyTray, mode_);
	assert(!label_.isNull());

	if (row == NULL)
		return; // nothing to do

	if (mode_ != SM_IGNORE || copyTray != NULL) {
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

		if (copyTray != NULL) {
			copyTray->push_back(rop);
		}
	}
}

void Gadget::sendDelayed(Tray *dest, const Row *row, Rowop::Opcode opcode, Tray *copyTray) const
{
	// fprintf(stderr, "DEBUG Gadget::sendDelayed(dest=%p, row=%p, opcode=0x%x, tray=%p) mode=%d\n", dest, row, opcode, copyTray, mode_);
	assert(!label_.isNull());

	if (row == NULL)
		return; // nothing to do

	if (mode_ != SM_IGNORE || copyTray != NULL) {
		Autoref<Rowop> rop = new Rowop(label_, opcode, row, mode_);
		if (mode_ != SM_IGNORE)
			dest->push_back(rop);
		if (copyTray != NULL)
			copyTray->push_back(rop);
	}
}

}; // BICEPS_NS
