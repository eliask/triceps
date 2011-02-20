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

Label::Label(Unit *unit, Onceref<const RowType> rtype) :
	type_(rtype)
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

void Label::call(Unit *unit, const Rowop *arg) const
{
	execute(arg);
	unit->drainFrame(); // avoid overlapping the row scheduling
	if (!chained_.empty()) {
		for (ChainedVec::const_iterator it = chained_.begin(); it != chained_.end(); ++it)
			(*it)->call(unit, arg); // each of them can do their own chaining....
	}
}

}; // BICEPS_NS
