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

class Table : public Mtarget
{
public:
	Table(const TableType *tt, const RowType *rowt, const RowHandleType *handt, const IndexTypeVec &topIt);

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

protected:
	Autoref<const TableType> type_; // type where this table belongs
	Autoref<const RowType> rowType_; // type of rows stored here
	Autoref<const RowHandleType> rhType_;
	IndexVec topInd_; // top-level indexes
};

}; // BICEPS_NS

#endif // __Biceps_Table_h__
