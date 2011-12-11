//
// (C) Copyright 2011 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// CEP code label.

#include <sched/Rowop.h>
#include <sched/Label.h>
#include <sched/Unit.h>

namespace TRICEPS_NS {

////////////////////////////////////// Label /////////////////////////////////

Label::Label(Unit *unit, const_Onceref<RowType> rtype, const string &name) :
	type_(rtype),
	unit_(unit),
	name_(name),
	cleared_(false)
{
	assert(unit);
	assert(!type_.isNull());
	unit->rememberLabel(this);
}

Label::~Label()
{ }

// not inside the function, or it will be initialized in screwed-up order
static string placeholderUnitName = "[label cleared]";
const string &Label::getUnitName() const
{
	return cleared_? placeholderUnitName : unit_->getName();
}

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
	ChainedVec path;
	if (lab.get() == this || lab->findChained(this, path)) {
		Erref err = new Errors;
		err->appendMsg(true, "labels must not be chained in a loop");
		string dep = "  " + getName() + "->" + lab->getName();
		while (!path.empty()) {
			dep += "->";
			dep += path.back()->getName();
			path.pop_back();
		}
		err->appendMsg(true, dep);
		return err;
	}

	chained_.push_back(lab);
	return NULL;
}

void Label::clearChained()
{
	chained_.clear();
}

void Label::clear()
{
	clearSubclass();
	clearChained();
	cleared_ = true;
}

void Label::clearSubclass()
{ }

void Label::call(Unit *unit, Rowop *arg, const Label *chainedFrom) const
{
	if (cleared_) // don't try to execute a cleared label
		return;
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

bool Label::findChained(const Label *target, ChainedVec &path) const
{
	for (ChainedVec::const_iterator it = chained_.begin(); it != chained_.end(); ++it) {
		if ( it->get() == target || (*it)->findChained(target, path) ) {
			path.push_back(*it);
			return true;
		}
	}
	return false;
}

//////////////////////////////// DummyLabel ///////////////////////////////////////////

void DummyLabel::execute(Rowop *arg) const
{ }


}; // TRICEPS_NS
