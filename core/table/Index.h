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

	// Remove the row from the index.
	// @param rh - handle to remove
	virtual void remove(RowHandle *rh) = 0;

	// Collapse the groups identified by this RowHandle set recursively
	// if they are found to be empty. "Collapsing" of a group means that the group
	// that became empty gets removed from its parent index and deleted.
	//
	// The handle would normally be removed from the table just a momemnt ago, so
	// its leaf iterators will be invalid, and the leaf indexes must
	// do nothing othen than return the result. However the non-leaf iterators 
	// would still point to the valid groups.
	// 
	// A tricky part is that multiple handles in the set may point to the
	// same group. Collapsing the group on the first matching row found will make
	// the iterators in the following rows belonging to the same group invalid.
	// So the index must first split the set into subsets by iterators
	// and then collapse only once.
	//
	// A group may be collapsed only if all its sub-indexes agree so. The reason
	// for non-collapsing may be the desire to avoid re-creating the group if
	// it gets inserted in the future. For example, the RootIndex never collapses
	// its only group. But this should not be a concern for the row replacement:
	// before the collapse is called, the new record would be already inserted,
	// making the group non-empty, and consequently non-collapsible.
	// 
	// @param replaced - set of rows that have been replaced, identifying the
	//     groups that may need collapsing.
	// @return - true if the index doesn't mind its parent group being collapsed
	//     (and did its part by collapsing all the sub-groups owned by it),
	//     false otherwise. For the leaf indexes it's safe to always return
	//     true, their parents will never collapse the non-empty groups.
	virtual bool collapse(const RhSet &replaced) = 0;
	
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
