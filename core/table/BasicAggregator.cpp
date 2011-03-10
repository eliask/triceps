//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Aggregator through a basic C-style callback function.

#include <type/BasicAggregatorType.h>
#include <table/BasicAggregator.h>
#include <sched/AggregatorGadget.h>

namespace BICEPS_NS {

void BasicAggregator::handle(Table *table, AggregatorGadget *gadget, Index *index,
	const IndexType *parentIndexType, GroupHandle *gh,
	AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
{
	const BasicAggregatorType *at = static_cast<const BasicAggregatorType *>(gadget->getType());
	at->cb_(table, gadget, index, parentIndexType, gh, aggop, opcode, rh, copyTray);
}

}; // BICEPS_NS
