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

Label::Label(Unit *unit, Onceref<const RowType> rtype, const string &name) :
	type_(rtype),
	unit_(unit),
	name_(name)
{
	assert(unit);
	assert(rtype.get());
}

Label::~Label()
{ }

bool Label::chain(Onceref<Label> lab)
{
	if (!type_->equals(lab->type_))
		return false;

	chained_.push_back(lab);
	return true;
}

void Label::clearChained()
{
	chained_.clear();
}

void Label::call(Unit *unit, const Rowop *arg, const Label *chainedFrom) const
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

void DummyLabel::execute(const Rowop *arg) const
{ }


}; // BICEPS_NS
