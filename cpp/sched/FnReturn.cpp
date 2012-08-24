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
		throw Exception::fTrace("Attempted to add label '%s' to an initialized FnReturn '%s'.", lname.c_str(), name_.c_str());

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
		throw Exception::fTrace("Attempted to add label '%s' to an initialized FnReturn '%s'.", lname.c_str(), name_.c_str());
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
		throw Exception::fTrace("Attempted to get the type from an uninitialized FnReturn '%s'.", name_.c_str());
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

void FnReturn::push(Onceref<FnBinding> bind)
{
	if (!type_->match(bind->getType())) 
		throw Exception::fTrace("Attempted to push a mismatching binding on the FnReturn '%s'.", name_.c_str());
	if (!initialized_)
		throw Exception::fTrace("Attempted to push a binding on an uninitialized FnReturn '%s'.", name_.c_str());
	stack_.push_back(bind);
}

void FnReturn::pushUnchecked(Onceref<FnBinding> bind)
{
	if (!initialized_)
		throw Exception::fTrace("Attempted to push a binding on an uninitialized FnReturn '%s'.", name_.c_str());
	stack_.push_back(bind);
}

void FnReturn::pop()
{
	if (stack_.empty())
		throw Exception::fTrace("Attempted to pop from an empty FnReturn '%s'.", name_.c_str());
	stack_.pop_back();
}

void FnReturn::pop(Onceref<FnBinding> bind)
{
	if (stack_.empty())
		throw Exception::fTrace("Attempted to pop from an empty FnReturn '%s'.", name_.c_str());
	FnBinding *top = stack_.back();
	if (top != bind)
		throw Exception::fTrace("Attempted to pop an unexpected binding from FnReturn '%s'.", name_.c_str());
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
// ScopeFnBind

ScopeFnBind::ScopeFnBind(Onceref<FnReturn> ret, Onceref<FnBinding> binding)
{
	ret->push(binding); // this might throw
	// Set the elements only after the dangers of throwing are over.
	ret_= ret;
	binding_ = binding;
}

ScopeFnBind::~ScopeFnBind()
{
	try {
		ret_->pop(binding_);
	} catch (Exception e) {
		// Make sure that the references get cleaned. Since this object
		// itself is allocated on the stack, there should be no memory
		// leak by throwing in the destructor, even when it doesn't abort.
		ret_ = NULL;
		binding_ = NULL;
		throw;
	}
}

///////////////////////////////////////////////////////////////////////////
// AutoFnBind

AutoFnBind *AutoFnBind::add(Onceref<FnReturn> ret, Autoref<FnBinding> binding)
{
	ret->push(binding);
	rets_.push_back(ret);
	bindings_.push_back(binding);
	return this;
}

void AutoFnBind::clear()
{
	// Pop in the opposite order. This is not a must, since presumably all the
	// FnReturns should be different. But just in case.
	Erref err;
	for (int i = rets_.size()-1; i >= 0; i--) {
		try {
			// fprintf(stderr, "DEBUG popping FnReturn '%s'\n", rets_[i]->getName().c_str());
			rets_[i]->pop(bindings_[i]);
		} catch (Exception e) {
			// fprintf(stderr, "DEBUG caught\n");
			errefAppend(err, strprintf("AutoFnBind::clear: caught an exception at position %d", i), e.getErrors());
		}
	}
	rets_.clear(); bindings_.clear();
	if (err->hasError()) {
		// fprintf(stderr, "DEBUG AutoFnBind::clear throwing\n");
		throw Exception(err, false); // no need to add stack, already in the messages
	}
}

AutoFnBind::~AutoFnBind()
{
	clear();
}

}; // TRICEPS_NS
