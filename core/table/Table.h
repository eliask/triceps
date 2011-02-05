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

protected:
	Autoref<const TableType> type_; // type where this table belongs
	Autoref<const RowType> rowType_; // type of rows stored here
	Autoref<const RowHandleType> rhType_;
	IndexVec topInd_; // top-level indexes
};

}; // BICEPS_NS

#endif // __Biceps_Table_h__
