//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class of user-defined factory of user-defined aggregators.

#include <type/AggregatorType.h>
#include <type/TableType.h>
#include <sched/AggregatorGadget.h>

namespace BICEPS_NS {

AggregatorType::AggregatorType(const string &name, const RowType *rt) :
	Type(false, TT_AGGREGATOR),
	rtype_(rt),
	name_(name),
	pos_(-1)
{
}

void AggregatorType::initialize(TableType *tabtype, IndexType *intype)
{
	initialized_ = true;
}

Erref AggregatorType::getErrors() const
{
	return errors_;
}

}; // BICEPS_NS
