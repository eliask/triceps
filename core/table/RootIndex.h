//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The pseudo-index for the root of the index tree.

#ifndef __Biceps_RootIndex_h__
#define __Biceps_RootIndex_h__

#include <table/Index.h>
#include <type/RootIndexType.h>

namespace BICEPS_NS {

class RootIndexType;
class RowType;

class RootIndex: public Index
{
	friend class RootIndexType;
public:
	// @param tabtype - type of table where this index belongs
	// @param table - the actual table where this index belongs
	// @param mytype - type that created this index
	RootIndex(const TableType *tabtype, Table *table, const RootIndexType *mytype);
	~RootIndex();

	// from Index
	virtual void clearData();
	virtual const IndexType *getType() const;
	virtual RowHandle *begin() const;
	virtual RowHandle *next(RowHandle *cur) const;
	virtual RowHandle *nextGroup(RowHandle *cur) const;
	virtual RowHandle *find(RowHandle *what) const;
	virtual Index *findNested(RowHandle *what, int nestPos) const;
	virtual bool replacementPolicy(RowHandle *rh, RhSet &replaced) const;
	virtual void insert(RowHandle *rh);
	virtual void remove(RowHandle *rh);

	// Get the number of records in this index
	size_t size();

protected:
	Autoref<const RootIndexType> type_; // type of this index
	GroupHandle *rootg_; // the root group
};

}; // BICEPS_NS

#endif // __Biceps_RootIndex_h__
