//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class of user-defined factory of user-defined aggregators.

#include <typeinfo>
#include <type/AggregatorType.h>
#include <type/TableType.h>
#include <sched/AggregatorGadget.h>

namespace TRICEPS_NS {

AggregatorType::AggregatorType(const string &name, const RowType *rt) :
	Type(false, TT_AGGREGATOR),
	rowType_(rt),
	name_(name),
	pos_(-1),
	initialized_(false)
{ 
	assert(rt != NULL);
}

AggregatorType::AggregatorType(const AggregatorType &agg) :
	Type(false, TT_AGGREGATOR),
	rowType_(agg.rowType_),
	name_(agg.name_),
	pos_(-1),
	initialized_(false)
{ }

AggregatorType::~AggregatorType()
{ }

void AggregatorType::initialize(TableType *tabtype, IndexType *intype)
{
	initialized_ = true;
}

Erref AggregatorType::getErrors() const
{
	return errors_;
}

bool AggregatorType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;
	
	if (typeid(*this) != typeid(*t)) // must be the same subclass
		return false;

	const AggregatorType *at = static_cast<const AggregatorType *>(t);

	if (!rowType_->equals(at->getRowType()))
		return false;

	if (name_ != at->getName())
		return false;

	return true;
}

bool AggregatorType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t)) {
		return false;
	}
	
	if (typeid(*this) != typeid(*t)) { // must be the same subclass
		return false;
	}

	const AggregatorType *at = static_cast<const AggregatorType *>(t);

	if (!rowType_->match(at->getRowType())) {
		return false;
	}

	return true;
}

void AggregatorType::printTo(string &res, const string &indent, const string &subindent) const
{
	string bufindent;
	const string &passni = nextindent(indent, subindent, bufindent);

	res.append("aggregator (");

	newlineTo(res, passni);
	rowType_->printTo(res, passni, subindent);

	newlineTo(res, indent);
	res.append(") ");
	res.append(name_);
}

}; // TRICEPS_NS
