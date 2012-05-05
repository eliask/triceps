//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// CEP code label.

#include <sched/Rowop.h>
#include <sched/Label.h>
#include <sched/Unit.h>
#include <common/Exception.h>
#include <common/BusyMark.h>

namespace TRICEPS_NS {

////////////////////////////////////// Label /////////////////////////////////

Label::Label(Unit *unit, const_Onceref<RowType> rtype, const string &name) :
	type_(rtype),
	unit_(unit),
	name_(name),
	cleared_(false),
	busy_(false)
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
	Erref err;
	try {
		clearSubclass();
	} catch (Exception e) {
		err = e.getErrors();
	}
	clearChained();
	cleared_ = true;
	if (!err.isNull())
		throw Exception(err, false);
}

void Label::clearSubclass()
{ }

void Label::call(Unit *unit, Rowop *arg, const Label *chainedFrom) const
{
	Erref err;

	if (cleared_) // don't try to execute a cleared label
		return;

	if (busy_) {
		throw Exception(strprintf("Detected a recursive call of the label '%s'.", getName().c_str()), false);
	}
	if (unit != unit_) {
		throw Exception(strprintf("Triceps API violation: call() attempt with unit '%s' of label '%s' belonging to unit '%s'.\n", 
			unit->getName().c_str(), getName().c_str(), unit_->getName().c_str()), true);
	}

	BusyMark bm(busy_);

	// XXX this code would be cleaner without exceptions...
	try {
		unit->trace(this, chainedFrom, arg, Unit::TW_BEFORE);
	} catch (Exception e) {
		err = new Errors;
		err->append(strprintf("Error when tracing before the label '%s':", getName().c_str()), e.getErrors());
		throw Exception(err, false);
	}
	try {
		execute(arg);
	} catch (Exception e) {
		err = e.getErrors();
		err->appendMsg(true, strprintf("Called through the label '%s'.", getName().c_str()));
		throw Exception(err, false);
	}
	try {
		unit->trace(this, chainedFrom, arg, Unit::TW_BEFORE_DRAIN);
	} catch (Exception e) {
		err = new Errors;
		err->append(strprintf("Error when tracing before draining the label '%s':", getName().c_str()), e.getErrors());
		throw Exception(err, false);
	}
	try {
		unit->drainFrame(); // avoid overlapping the row scheduling
	} catch (Exception e) {
		err = e.getErrors();
		err->appendMsg(true, strprintf("Called when draining the frame of label '%s'.", getName().c_str()));
		throw Exception(err, false);
	}
	if (!chained_.empty()) {
		try {
			unit->trace(this, chainedFrom, arg, Unit::TW_BEFORE_CHAINED);
		} catch (Exception e) {
			err = new Errors;
			err->append(strprintf("Error when tracing before the chain of the label '%s':", getName().c_str()), e.getErrors());
			throw Exception(err, false);
		}
		for (ChainedVec::const_iterator it = chained_.begin(); it != chained_.end(); ++it) {
			try {
				(*it)->call(unit, arg, this); // each of them can do their own chaining....
			} catch (Exception e) {
				err = e.getErrors();
				err->appendMsg(true, strprintf("Called chained from the label '%s'.", getName().c_str()));
				throw Exception(err, false);
			}
		}
	}
	try {
		unit->trace(this, chainedFrom, arg, Unit::TW_AFTER);
	} catch (Exception e) {
		err = new Errors;
		err->append(strprintf("Error when tracing after execution of the label '%s':", getName().c_str()), e.getErrors());
		throw Exception(err, false);
	}
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
