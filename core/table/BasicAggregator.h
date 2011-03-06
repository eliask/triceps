//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Aggregator through a basic C-style callback function.

#ifndef __Biceps_BasicAggregator_h__
#define __Biceps_BasicAggregator_h__

#include <table/Aggregator.h>

namespace BICEPS_NS {

class AggregatorGadget;
class Table;

class BasicAggregator : public Aggregator
{
public:
	BasicAggregator(Table *table, AggregatorGadget *gadget) :
		gadget_(gadget)
	{ }

	// from Aggregator
	virtual void handle(Table *table, AggregatorGadget *gadget, Index *index,
		const IndexType *parentIndexType, GroupHandle *gh,
		AggOp aggop, Rowop::Opcode opcode, RowHandle *rh);

protected:
	// In more complex aggregators the gadget would be of a subtype
	AggregatorGadget *gadget_;
};

}; // BICEPS_NS

#endif // __Biceps_BasicAggregator_h__
