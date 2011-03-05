//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class for aggregators.

#ifndef __Biceps_Aggregator_h__
#define __Biceps_Aggregator_h__

#include <sched/Rowop.h>
#include <table/RowHandle.h>

namespace BICEPS_NS {

class Index;
class AggregatorGadget;

// The Aggregator is always owned by the index group (OK, logically it can be thought
// that it's owned by an index but really by a group), which always works single-threaded.
// So there is not much point in refcounting it, and this saves a few bytes pre instance.
class Aggregator
{
public:
	virtual ~Aggregator();

	// Should there be one virtual functions with an operation selector argument
	// or multiple virtual functions? There are benefits in both solutions, so
	// for now pick the one that should be easier to interface with C and Perl code.
	
	// Operation selector
	enum AggOp {
		AO_BEFORE_MOD, // before modification
		AO_AFTER_DELETE, // after row removal has been performed
		AO_AFTER_INSERT, // after row insertion was performed
		AO_COLLAPSE, // when the group is being collapsed, must not access index any more
	};

	// Handle one operation on the group.
	// Updates the internal state of the aggregator and possibly sends information
	// about the changes to the Gadget.
	//
	// @param table - table on which the change happens
	// @param gadget - gadget of this aggregator, where to send the Rowops
	// @param index - index on which this aggregator is defined, contains the row of the group
	// @param aggop - the reason for this call
	// @param opcode - the Rowop opcode that would be normally used for the records
	//        produced in this operation (INSERT, DELETE, NOP), so that the simpler
	//        aggregators can ignore aggop and just go by opcode
	// @param rh - row that has been inderted or deleted, if deleted then it will be
	//        already not in table; may be NULL if aggop just requires the sending of
	//        the old state
	virtual void handle(Table *table, AggregatorGadget *gadget, Index *index,
		AggOp aggop, Rowop::Opcode opcode, RowHandle *rh) = 0;
};

}; // BICEPS_NS

#endif // __Biceps_Aggregator_h__
