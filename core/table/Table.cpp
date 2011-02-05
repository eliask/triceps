//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The table implementation.

#include <table/Table.h>
#include <type/TableType.h>

namespace BICEPS_NS {

Table::Table(const TableType *tt, const RowType *rowt, const RowHandleType *handt, const IndexTypeVec &topIt) :
	type_(tt),
	rowType_(rowt),
	rhType_(handt)
{ 
	tt->topInd_.makeIndexes(tt, this, &topInd_);
}

}; // BICEPS_NS

