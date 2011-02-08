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

// mirrors IndexTypeRef
// connection of indexes into a tree
class  IndexRef 
{
public:
	IndexRef(const string &n, Index *i);
	IndexRef();

	string name_; // name of the index, for finding it later
	Autoref<Index> index_;
};

// mirrors IndexTypeVec
class IndexVec: public  vector<IndexRef>
{
public:
	IndexVec();
	IndexVec(size_t size);
	// Populate with the copy of the original types
	// IndexVec(const IndexVec &orig);

	// Find the nested index by name.
	// @param name - name of the nested index
	// @return - pointer to the nested index or NULL if unknown name
	Index *find(const string &name) const;
	
	// Find the first nested index of given type.
	// @param it - type enum of the nested index
	// @return - pointer to the nested index or NULL if none matches
	Index *findByType(IndexType::IndexId it) const;

protected:
	friend class Table;
	friend class Index;

	typedef set<RowHandle *> RhSet;

	// Clear the contents of the indexes. The actual RowHandles are guaranteed
	// to be still held by the table, so the cleaning can be fast.
	void clearData() const;

	// Initialize the row handle section for this index and its nested ones:
	// pre-calculate the has values and such for the given row.
	void initRowHandle(RowHandle *rh) const;

	// Clear any references to these indexes' dynamically allocated data
	// from this handle.
	void clearRowHandle(RowHandle *rh) const;

	// Prepare all indexes for insertion of the new row handle.
	// Check if it can legally inserted and calculate any records that
	// would be deleted by the replacement policy.
	// If any indexes return false, returns immediately without calling all.
	// @param rh - new row about to be inserted
	// @param replaced - set to add the handles of replaced rows
	// @return - true if insertion is allowed, false if not
	bool replacementPolicy(RowHandle *rh, RhSet &replaced) const;

	// Insert the row into all indexes.
	// @param rh - handle to insert
	void insert(RowHandle *rh) const;

	// Remove the row from all indexes.
	// @param rh - handle to remove
	void remove(RowHandle *rh) const;

private:
	void operator=(const IndexVec &);
};

// Indexes should be accessed only in one thread, so maybe Straget 
// would be a better choice.
class Index : public Mtarget
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
	virtual RowHandle *next(RowHandle *cur) const = 0;

	// For the nested indexes, a way to skip over all the
	// remaining records in the current group.
	// @param - the current handle
	// @return - handle of the first row in the next group, or NULL if the 
	//       current one was the last one, or not in the table or NULL
	virtual RowHandle *nextGroup(RowHandle *cur) const = 0;

	// Find the matching element.
	// Note that for a RowHandle that has been returned from the table
	// there is no sense in calling find() because it already represents
	// an iterator in the table. This finds a row in the table with the
	// key matching one in a freshly made RowHandle (with Table::makeRowHandle()).
	// @param what - the pattern row
	// @return - the matching (accoriding to this index) row in the table,
	//     or NULL if not found; an index that has multiple matching rows,
	//     may return any of them but preferrably the first one.
	virtual RowHandle *find(RowHandle *what) const = 0;

	// XXX add lower_bound, upper_bound ?

	// Find the nested index by name.
	// @param name - name of the index
	// @return - index, or NULL if not found
	Index *findIndex(const string &name) const
	{
		return nested_.find(name);
	}

	// Find the first nested index of given type.
	// @param it - type enum of the nested index
	// @return - pointer to the nested index or NULL if none matches
	Index *findIndexByType(IndexType::IndexId it) const
	{
		return nested_.findByType(it);
	}

	// Return the indev vector.
	const IndexVec &getIndexVec() const
	{
		return nested_;
	}

	// Get the type id of this index
	IndexType::IndexId getIndexId() const
	{
		return getType()->getIndexId();
	}

protected:
	typedef set<RowHandle *> RhSet;

	// always created through subclasses
	Index(const TableType *tabtype, Table *table);
	
	// Clear the contents of the index. The actual RowHandles are guaranteed
	// to be still held by the table, so the cleaning can be fast.
	virtual void clearData() = 0;

	// Initialize the row handle section for this index and its nested ones:
	// pre-calculate the has values and such for the given row.
	// Normally only the Table class should call it (maybe through IndexVec).
	virtual void initRowHandle(RowHandle *rh) const = 0;

	// Initialize the row handle for nested indexes.
	// (to make the compiler happy for calls from subclasses)
	void initRowHandleNested(RowHandle *rh) const
	{
		nested_.initRowHandle(rh);
	}

	// Clear any references to this index's dynamically allocated data
	// from this handle.
	virtual void clearRowHandle(RowHandle *rh) const = 0;
	// (to make the compiler happy for calls from subclasses)
	void clearRowHandleNested(RowHandle *rh) const
	{
		nested_.initRowHandle(rh);
	}

	// Prepare for insertion of the new row handle.
	// Check if it can legally inserted and calculate any records that
	// would be deleted by the replacement policy.
	// XXX should it also have an indication of update vs insert?
	// @param rh - new row about to be inserted
	// @param replaced - set to add the handles of replaced rows
	// @return - true if insertion is allowed, false if not
	virtual bool replacementPolicy(RowHandle *rh, RhSet &replaced) const = 0;
	// (to make the compiler happy for calls from subclasses)
	bool replacementPolicyNested(RowHandle *rh, RhSet &replaced) const
	{
		return nested_.replacementPolicy(rh, replaced);
	}

	// Insert the row into the index.
	// This is called after the replacement policy has been executed.
	// @param rh - handle to insert
	virtual void insert(RowHandle *rh) = 0;
	// (to make the compiler happy for calls from subclasses)
	void insertNested(RowHandle *rh) 
	{
		nested_.insert(rh);
	}

	// Remove the row from the index.
	// @param rh - handle to remove
	virtual void remove(RowHandle *rh) = 0;
	// (to make the compiler happy for calls from subclasses)
	void removeNested(RowHandle *rh) 
	{
		nested_.remove(rh);
	}

protected:
	IndexVec nested_; // nested indices
	// no reference to the type because they're better in subclasses
	Autoref<const TableType> tabType_; // type of the table where it belongs
	Table *table_; // not Autoref, to avoid circularf references

private:
	Index();
	Index(const Index &);
	void operator=(const Index &);
};

}; // BICEPS_NS

#endif // __Biceps_Index_h__
