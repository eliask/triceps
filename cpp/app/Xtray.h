//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A tray for passing the rowops across the nexuses.

#ifndef __Triceps_Xtray_h__
#define __Triceps_Xtray_h__

#include <vector>
#include <common/Common.h>
#include <sched/Rowop.h>
#include <type/RowSetType.h>

namespace TRICEPS_NS {

// It's like a tray but carries the rowops in a special representation
// to the different trays.
// The memory management is a bit weird, with Xtray directly controlling the
// references to all the rows in it (as opposed to the normal Rowop doing
// its own control and normal Tray just collecting the rowops).
//
// The normal lifecycle of an Xtray is to be created on one thread,
// then sent to a Nexus. Then be read from there by the other threads.
// Once the Xtray is populated and sent on, it becomes fixed and
// can not be modified any more. As long as this rule is observed,
// there is no need for synchronization for the data access.
// The only item that needs synchronization is the Mtarget reference count.
class Xtray: public Mtarget
{
public:
	// One rowop equivalent for traveling through the nexus.
	class Op
	{
	public:
		// The constructor silently strips the const-ness of the row.
		Op(int idx, const Row *row, Rowop::Opcode op):
			row_(const_cast<Row *>(row)),
			idx_(idx),
			opcode_(op)
		{ }

		Row *row_; // will be referenced manually when Op is inserted into Xtray
		int idx_; // index of this row's type in the nexus type; -1 has a special meaning:
			// the boundary between multiple transactions clumped into one Xtray,
			// in this case row_ must be NULL
		Rowop::Opcode opcode_;
	};

	// Create an xtray for a nexus.
	// @param rst - type of the nexus
	Xtray(RowSetType *rst);
	~Xtray();

	// Get the number of ops.
	int size() const
	{
		return (int)ops_.size();
	}

	// Add a new Op.
	// @param data - a prototype to add
	void push_back(const Op &data);

	// Add a new Op from individual elements.
	void push_back(int idx, const Row *row, Rowop::Opcode opcode)
	{
		push_back(Op(idx, row, opcode));
	}

	// Get an op at the index.
	// @param idx - the index to read at, must be within the size
	// @return - the element reference, that must not be modified
	const Op &at(int idx) const
	{
		return ops_[idx];
	}

protected:
	Autoref<RowSetType> type_; // type of the nexus, also row types from it are used
		// to un-reference the Rows and destroy them if needed
	typedef vector<Op> OpVec;
	OpVec ops_; // the data

private:
	Xtray();
	Xtray(const Xtray &);
	void operator=(const Xtray &);
};

}; // TRICEPS_NS

#endif // __Triceps_Xtray_h__
