//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Representation of a streaming function return.

#include <sched/FnReturn.h>
#include <sched/Unit.h>

namespace TRICEPS_NS {

FnReturn::FnReturn(Unit *unit, const string &name) :
	unit_(unit),
	name_(name),
	type_(new RowSetType),
	initialized_(false)
{ }

FnReturn *FnReturn::addFromLabel(const string &lname, Autoref<Label>from)
{
	if (initialized_)
		throw Exception("Triceps API violation: attempt to add label '" + lname + "' to an initialized FnReturn.", true);

	if (from->getUnitPtr() != unit_) {
		// if the unit in the from label is NULL, this will crash
		type_->addError("Can not include the label '" + from->getName() 
			+ "' into the FnReturn as '" + lname + "': it has a different unit, '"
			+ from->getUnitPtr()->getName() + "' vs '" + unit_->getName() + "'.");
	} else {
		const RowType *rtype = from->getType();
		int szpre = type_->size();
		type_->addRow(lname, rtype);
		if (type_->size() != szpre) {
			// type detected no error
			Autoref<Label> lb = new DummyLabel(unit_, rtype, name_ + "." + lname);
			labels_.push_back(lb);
			Erref cherr = from->chain(lb);
			if (cherr->hasError())
				type_->appendErrors()->append("Failed the chaining of label '" + lname + "':", cherr);
		}
	}
	return this;
}

FnReturn *FnReturn::addDummyLabel(const string &lname, const_Autoref<RowType>rtype)
{
	if (initialized_)
		throw Exception("Triceps API violation: attempt to add label '" + lname + "' to an initialized FnReturn.", true);
	int szpre = type_->size();
	type_->addRow(lname, rtype);
	if (type_->size() != szpre) {
		// type detected no error
		Autoref<Label> lb = new DummyLabel(unit_, rtype, name_ + "." + lname);
		labels_.push_back(lb);
	}
	return this;
}

RowSetType *FnReturn::getType() const
{
	if (!initialized_)
		throw Exception("Triceps API violation: attempt to get the type from an uninitialized FnReturn.", true);
	return type_;
}

bool FnReturn::equals(const FnReturn *t) const
{
	return type_->equals(t->type_);
}

bool FnReturn::match(const FnReturn *t) const
{
	return type_->match(t->type_);
}

Label *FnReturn::getLabel(const string &name) const
{
	return getLabel(type_->findName(name));
}

int FnReturn::findLabel(const string &name) const
{
	return type_->findName(name);
}

Label *FnReturn::getLabel(int idx) const
{
	if (idx >= 0 && idx < labels_.size())
		return labels_[idx];
	else
		return NULL;
}

}; // TRICEPS_NS
