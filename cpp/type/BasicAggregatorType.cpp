//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Aggregator through a basic C-style callback function.

#include <type/BasicAggregatorType.h>
#include <table/BasicAggregator.h>
#include <sched/AggregatorGadget.h>

namespace TRICEPS_NS {

BasicAggregatorType::BasicAggregatorType(const string &name, const RowType *rt, Callback *cb) :
	AggregatorType(name, rt),
	cb_(cb)
{ }

AggregatorType *BasicAggregatorType::copy() const
{
	return new BasicAggregatorType(*this);
}

AggregatorGadget *BasicAggregatorType::makeGadget(Table *table, IndexType *intype) const
{
	return new AggregatorGadget(this, table, intype);
}

Aggregator *BasicAggregatorType::makeAggregator(Table *table, AggregatorGadget *gadget) const
{
	return new BasicAggregator(table, gadget);
}

}; // TRICEPS_NS
