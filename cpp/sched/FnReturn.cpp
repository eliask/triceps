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
			Autoref<RetLabel> lb = new RetLabel(unit_, rtype, name_ + "." + lname, this, szpre);
			labels_.push_back(lb);
			Erref cherr = from->chain(lb);
			if (cherr->hasError())
				type_->appendErrors()->append("Failed the chaining of label '" + lname + "':", cherr);
		}
	}
	return this;
}

FnReturn *FnReturn::addLabel(const string &lname, const_Autoref<RowType>rtype)
{
	if (initialized_)
		throw Exception("Triceps API violation: attempt to add label '" + lname + "' to an initialized FnReturn.", true);
	int szpre = type_->size();
	type_->addRow(lname, rtype);
	if (type_->size() != szpre) {
		// type detected no error
		Autoref<RetLabel> lb = new RetLabel(unit_, rtype, name_ + "." + lname, this, szpre);
		labels_.push_back(lb);
	}
	return this;
}

FnReturn *FnReturn::initializeOrThrow()
{
	initialize();
	Erref err = getErrors();
	if (err->hasError()) {
		Autoref<FnReturn> r(this); // makes sure that a newly allocated "this" will get freed
		throw Exception(err, true);
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

void FnReturn::pushBinding(Onceref<FnBinding> bind)
{
	if (!initialized_)
		throw Exception("Triceps API violation: attempted to push a binding on an uninitialized FnReturn.", true);
	stack_.push_back(bind);
}

void FnReturn::popBinding()
{
	if (stack_.empty())
		throw Exception("Triceps API violation: attempted to pop from an empty FnReturn.", true);
	stack_.pop_back();
}

void FnReturn::popBinding(Onceref<FnBinding> bind)
{
	if (stack_.empty())
		throw Exception("Triceps API violation: attempted to pop from an empty FnReturn.", true);
	FnBinding *top = stack_.back();
	if (top != bind)
		throw Exception("Triceps API violation: popping an unexpected binding.", true);
		// XXX should give some better diagnostics, helping to find the root cause.
	stack_.pop_back();
}

///////////////////////////////////////////////////////////////////////////
// RetLabel

FnReturn::RetLabel::RetLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name,
	FnReturn *fnret, int idx
) :
	Label(unit, rtype, name),
	fnret_(fnret),
	idx_(idx)
{ }

void FnReturn::RetLabel::execute(Rowop *arg) const
{
	if (fnret_->stack_.empty())
		return; // no binding yet
	FnBinding *top = fnret_->stack_.back();
	Label *lab = top->getLabel(idx_);
	if (lab == NULL)
		return; // not bound here

	Unit *u = lab->getUnitPtr();
	if (u == NULL)
		return; // a cleared label, do not call

	// This can safely call another unit.
	Autoref<Rowop> adrop = new Rowop(lab, arg);
	u->call(adrop);
}

///////////////////////////////////////////////////////////////////////////
// AutoFnBind

AutoFnBind::AutoFnBind(Onceref<FnReturn> ret, Onceref<FnBinding> binding) :
	ret_(ret),
	binding_(binding)
{
	ret_->pushBinding(binding_);
}

AutoFnBind::~AutoFnBind()
{
	ret_->popBinding(binding_);
}

}; // TRICEPS_NS
