//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// CEP code label.

#include <sched/Rowop.h>
#include <sched/Label.h>
#include <sched/Unit.h>

namespace BICEPS_NS {

////////////////////////////////////// Label /////////////////////////////////

Label::Label(Unit *unit, const_Onceref<RowType> rtype, const string &name) :
	type_(rtype),
	unit_(unit),
	name_(name)
{
	assert(unit);
	assert(rtype.get());
}

Label::~Label()
{ }

Erref Label::chain(Onceref<Label> lab)
{
	assert(this != NULL);
	assert(!lab.isNull());
	if (!type_->equals(lab->type_)) {
		Erref err = new Errors;
		err->appendMsg(true, "can not chain labels with non-equal row types");
		err->appendMsg(true, "  " + getName() + ":");
		err->appendMsg(true, "    " + type_->print("    "));
		err->appendMsg(true, "  " + lab->getName() + ":");
		err->appendMsg(true, "    " + lab->type_->print("    "));
		return err;
	}

	chained_.push_back(lab);
	return NULL;
}

void Label::clearChained()
{
	chained_.clear();
}

void Label::call(Unit *unit, Rowop *arg, const Label *chainedFrom) const
{
	assert(unit == unit_); // XXX add some better way to report errors than crash? also check when scheduling a tray
	unit->trace(this, chainedFrom, arg, Unit::TW_BEFORE);
	execute(arg);
	unit->trace(this, chainedFrom, arg, Unit::TW_BEFORE_DRAIN);
	unit->drainFrame(); // avoid overlapping the row scheduling
	if (!chained_.empty()) {
		unit->trace(this, chainedFrom, arg, Unit::TW_BEFORE_CHAINED);
		for (ChainedVec::const_iterator it = chained_.begin(); it != chained_.end(); ++it)
			(*it)->call(unit, arg, this); // each of them can do their own chaining....
	}
	unit->trace(this, chainedFrom, arg, Unit::TW_AFTER);
}

//////////////////////////////// DummyLabel ///////////////////////////////////////////

void DummyLabel::execute(Rowop *arg) const
{ }


}; // BICEPS_NS
