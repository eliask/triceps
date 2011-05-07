//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class for aggregation gadgets.

#include <sched/AggregatorGadget.h>
#include <type/AggregatorType.h>
#include <type/RowType.h>
#include <type/TableType.h>
#include <table/Table.h>

namespace TRICEPS_NS {

AggregatorGadget::AggregatorGadget(const AggregatorType *type, Table *table, IndexType *intype) :
	Gadget(table->getUnit(), table->getEnqMode(), table->getName() + "." + type->getName(), type->getRowType()),
	table_(table),
	type_(type),
	indexType_(intype)
{ }

}; // TRICEPS_NS
