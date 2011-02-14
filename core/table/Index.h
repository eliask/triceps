//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The common interface for indexes.

#ifndef __Biceps_Index_h__
#define __Biceps_Index_h__

#include <mem/Mtarget.h>
#include <common/Common.h>
#include <type/IndexType.h>
#include <table/RowHandle.h>
#include <set>

namespace BICEPS_NS {

class TableType;
class IndexType;
class Table;
class Index;

// Indexes should be accessed only in one thread, so Straget is good enough.
class Index : public Starget
{
	friend class IndexType;
	friend class IndexVec;
	friend class Table;
public:
	virtual ~Index();

	// Get the type of this index: let the subclass sort it out
	virtual const IndexType *getType() const = 0;

	// Get the handle of the first record in this index.
	// @return - the handle, or NULL if the index is empty
	virtual RowHandle *begin() const = 0;

	// Return the next row in this index.
	// The repeated calls would go through all the records in the table.
	// So for the nested indexes this means that it should iterate
	// through any (usually, first) of the sub-indexes as well.
	// @param - the current handle
	// @return - the next row's handle, or NULL if the current one was the last one,
	//       or not in the table or NULL
	virtual RowHandle *next(const RowHandle *cur) const = 0;

	// For the nested indexes, a way to skip over all the
	// remaining records in the current group.
	// @param - the current handle
	// @return - handle of the first row in the next group, or NULL if the 
	//       current group was the last one, or row not in the table or NULL
	virtual RowHandle *nextGroup(const RowHandle *cur) const = 0;

	// Find the matching element.
	// Note that for a RowHandle that has been returned from the table
	// there is no sense in calling find() because it already represents
	// an iterator in the table. This finds a row in the table with the
	// key matching one in a freshly made RowHandle (with Table::makeRowHandle()).
	// @param what - the pattern row
	// @return - the matching (accoriding to this index) row in the table,
	//     or NULL if not found; an index that has multiple matching rows,
	//     may return any of them but preferrably the first one.
	virtual RowHandle *find(const RowHandle *what) const = 0;

	// XXX add lower_bound, upper_bound ?

	// Get the type id of this index
	IndexType::IndexId getIndexId() const
	{
		return getType()->getIndexId();
	}

protected:
	typedef set<RowHandle *> RhSet;

	// always created through subclasses
	Index(const TableType *tabtype, Table *table);
	
	// Clear the data rows of the index. For non-leaf indexes this
	// means the recursive propagation down to the leaves.
	// The contents of the non-leaf indexes does not get deleted,
	// and the groups are not collapsed.
	// The actual RowHandles are guaranteed
	// to be still held by the table, so the cleaning can be fast.
	virtual void clearData() = 0;

	// Prepare for insertion of the new row handle.
	// Check if it can legally inserted and calculate any records that
	// would be deleted by the replacement policy.
	// XXX should it also have an indication of update vs insert?
	// @param rh - new row about to be inserted
	// @param replaced - set to add the handles of replaced rows
	// @return - true if insertion is allowed, false if not
	virtual bool replacementPolicy(const RowHandle *rh, RhSet &replaced) const = 0;

	// Insert the row into the index.
	// This is called after the replacement policy has been executed.
	// @param rh - handle to insert
	virtual void insert(RowHandle *rh) = 0;
	// (to make the compiler happy for calls from subclasses)

	// Remove the row from the index.
	// @param rh - handle to remove
	virtual void remove(RowHandle *rh) = 0;
	// (to make the compiler happy for calls from subclasses)

	// If this is a non-leaf index, find the nested index
	// in the group where this row belongs.
	// @param what - row used to find the group
	// @param nestPos - position of wanted index type in its parent
	// @return - the index, or NULL if it can not be found
	//        (if this is a leaf index, it always returns NULL)
	virtual Index *findNested(const RowHandle *what, int nestPos) const = 0;

protected:
	// no reference to the type because they're better in subclasses
	Autoref<const TableType> tabType_; // type of the table where it belongs
	Table *table_; // not Autoref, to avoid circular references

private:
	Index();
	Index(const Index &);
	void operator=(const Index &);
};

}; // BICEPS_NS

#endif // __Biceps_Index_h__
