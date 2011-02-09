//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The table implementation.

#ifndef __Biceps_Table_h__
#define __Biceps_Table_h__

#include <type/TableType.h>
#include <table/Index.h>

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

	// Find an index by name
	// @param name - name of the index
	// @return - index, or NULL if not found
	Index *findIndex(const string &name) const
	{
		return topInd_.find(name);
	}

	// Find the first index of given type
	// @param it - type enum of the nested index
	// @return - pointer to the nested index or NULL if none matches
	Index *findIndexByType(IndexType::IndexId it) const
	{
		return topInd_.findByType(it);
	}

	// Return the indev vector.
	const IndexVec &getIndexVec() const
	{
		return topInd_;
	}

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
	RowHandle *next(RowHandle *cur) const;

protected:
	friend class Rhref;

	// called by Rhref when the last reference to a row handle is removed
	void destroyRowHandle(RowHandle *rh);

protected:
	Autoref<const TableType> type_; // type where this table belongs
	Autoref<const RowType> rowType_; // type of rows stored here
	Autoref<const RowHandleType> rhType_;
	IndexVec topInd_; // top-level indexes
};

}; // BICEPS_NS

#endif // __Biceps_Table_h__
