//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The table implementation.

#ifndef __Biceps_Table_h__
#define __Biceps_Table_h__

#include <type/TableType.h>
#include <table/RootIndex.h>

namespace BICEPS_NS {

class RowType;
class RowHandleType;
class TableType;
class Row;

class Table : public Mtarget
{
public:
	Table(const TableType *tt, const RowType *rowt, const RowHandleType *handt, const IndexTypeVec &topIt);
	~Table();

	// Get the type of this table
	const TableType *getType()
	{
		return type_;
	}
	// Get the row type of this table
	const RowType *getRowType()
	{
		return rowType_;
	}
	// Get the row handle type of this table
	const RowHandleType *getRhType()
	{
		return rhType_;
	}
	
	/////// operations on rows

	// Create a new row handle for a row.
	// The result should be immediately placed into Rhref.
	// XXX change the interface to make this protected and return Rhrefs to everyone else
	RowHandle *makeRowHandle(const Row *row);

	// Insert a row.
	// XXX add a way to get back the records removed by the replacement policies
	// @param row - the row to insert
	// @return - true on success, false on failure (if the index policies don't allow it)
	bool insert(const Row *row);
	// Insert a pre-initialized row handle.
	// If the handle is already in table, does nothing and returns false.
	// @param rh - the row handle to insert (must be held in a Rowref or such at the moment)
	// @return - true on success, false on failure (if the index policies don't allow it)
	bool insert(RowHandle *rh);

	// Remove a row handle from the table. If the row is already not in table, do nothing.
	// @param rh - row handle to remove
	void remove(RowHandle *rh);

	// Get the handle of the first record in this table.
	// A random index will be used for iteration. Usually this will be
	// the first index, but the table may decide to pick a more efficient one
	// if it can.
	// @return - the handle, or NULL if the table is empty
	RowHandle *begin() const;

	// Return the next row in this table.
	// @param - the current handle
	// @return - the next row's handle, or NULL if the current one was the last one,
	//       or not in the table or NULL
	RowHandle *next(const RowHandle *cur) const;

	// XXX doesn't work yet
	// For the nested indexes, a way to skip over all the
	// remaining records in the current group, according to an index.
	// @param ixt - index type from this table's type
	// @param cur - the current handle
	// @return - handle of the first row in the next group, or NULL if the 
	//       current group was the last one, or row not in the table or NULL
	RowHandle *nextGroup(IndexType *ixt, const RowHandle *cur) const;

	// Find the matching element.
	// Note that for a RowHandle that has been returned from the table
	// there is no sense in calling find() because it already represents
	// an iterator in the table. This finds a row in the table with the
	// key matching one in a freshly made RowHandle (with Table::makeRowHandle()).
	//
	// XXX should it allow non-leaf indexes and find the first record in group?
	//
	// @param ixt - leaf index type from this table's type
	// @param what - the pattern row
	// @return - the matching (accoriding to this index) row in the table,
	//     or NULL if not found or if the index is non-leaf; an index that has 
	//     multiple matching rows, may return any of them but preferrably the first one.
	RowHandle *find(IndexType *ixt, const RowHandle *what) const;

protected:
	friend class Rhref;

	// called by Rhref when the last reference to a row handle is removed
	void destroyRowHandle(RowHandle *rh);

protected:
	friend class IndexType;

	RootIndex *getRoot() const
	{
		return root_;
	}

protected:
	Autoref<const TableType> type_; // type where this table belongs
	Autoref<const RowType> rowType_; // type of rows stored here
	Autoref<const RowHandleType> rhType_;
	Autoref<RootIndex> root_; // root of the index tree
};

}; // BICEPS_NS

#endif // __Biceps_Table_h__
