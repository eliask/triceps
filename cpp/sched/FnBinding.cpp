//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Binding of a streaming function return to a set of concrete labels.


#include <sched/FnBinding.h>
#include <sched/FnReturn.h>
#include <sched/Unit.h>

namespace TRICEPS_NS {

FnBinding::FnBinding(FnReturn *fn)
{
	if (!fn->isInitialized()) {
		// avoid throwing an exception from constructor
		errors_ = new Errors;
		errors_->appendMsg(true, "Can not create a binding to an uninitialized FnReturn.");
	} else {
		type_ = fn->getType();
		labels_.resize(type_->size());
		autoclear_.resize(type_->size());
	}
}

FnBinding::~FnBinding()
{
	for (size_t i = 0; i < labels_.size(); i++) {
		if (!autoclear_[i])
			continue;
		Label *lb = labels_[i];
		Unit *u = lb->getUnitPtr();
		if (u) {
			u->forgetLabel(lb);
			lb->clear();
		}
	}
}

FnBinding *FnBinding::addLabel(const string &name, Autoref<Label> lb, bool autoclear)
{
	if (type_.isNull()) // type would be NULL if the FnReturn was uninitialized
		return this; // then ignore all the following errors

	int idx = type_->findName(name);
	if (idx < 0) {
		if (errors_.isNull())
			errors_ = new Errors;
		errors_->appendMsg(true, "Unknown return label name '" + name + "'.");
		return this;
	} 

	if (labels_.size() < idx+1) // should never happen but just in case
		labels_.resize(idx+1);
		autoclear_.resize(idx+1);

	if (!labels_[idx].isNull()) {
		if (errors_.isNull())
			errors_ = new Errors;
		errors_->appendMsg(true, "Attempted to add twice a label to name '" + name + "' (first '" 
			+ labels_[idx]->getName() + "', second '" + lb->getName() + "').");
		return this;
	}

	const RowType *fnrt = type_->getRowType(idx);
	const RowType *lbrt = lb->getType();
	if (!lbrt->match(fnrt)) {
		string msg;

		if (errors_.isNull())
			errors_ = new Errors;
		errors_->appendMsg(true, "Attempted to add a mismatching label '" + lb->getName() + "' to name '" + name + "'.");
		msg = "  The expected row type:\n  ";
		fnrt->printTo(msg, "    ");
		errors_->appendMultiline(true, msg);

		msg = "  The row type of actual label '" + lb->getName() + "':\n  ";
		lbrt->printTo(msg, "    ");
		errors_->appendMultiline(true, msg);

		return this;
	}

	labels_[idx] = lb;
	autoclear_[idx] = autoclear;
	return this;
}

FnBinding *FnBinding::checkOrThrow()
{
	Erref err = getErrors();
	if (err->hasError()) {
		Autoref<FnBinding> r(this); // makes sure that a newly allocated "this" will get freed
		throw Exception(err, true);
	}
	return this;
}

Label *FnBinding::getLabel(int idx) const
{
	if (idx < 0 || idx >= labels_.size())
		return NULL;
	return labels_[idx];
}

}; // TRICEPS_NS
