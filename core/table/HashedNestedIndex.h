//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key with further nesting.

#ifndef __Biceps_HashedNestedIndex_h__
#define __Biceps_HashedNestedIndex_h__

#include <table/Index.h>
#include <type/HashedIndexType.h>

namespace BICEPS_NS {

class HashedIndexType;
class RowType;

class HashedNestedIndex: public Index
{
	friend class HashedIndexType;

public:
	typedef HashedIndexType::Less Less;
	typedef HashedIndexType::RhSection RhSection;
	typedef HashedIndexType::Set Set;

	// @param tabtype - type of table where this index belongs
	// @param table - the actual table where this index belongs
	// @param mytype - type that created this index
	// @param lessop - less functor class for the key, this index assumes is ownership
	HashedNestedIndex(const TableType *tabtype, Table *table, const HashedIndexType *mytype, Less *lessop);
	~HashedNestedIndex();

	// from Index
	virtual void clearData();
	virtual const IndexType *getType() const;
	virtual RowHandle *begin() const;
	virtual RowHandle *next(const RowHandle *cur) const;
	virtual RowHandle *nextGroup(const RowHandle *cur) const;
	virtual RowHandle *find(const RowHandle *what) const;
	virtual bool replacementPolicy(const RowHandle *rh, RhSet &replaced);
	virtual void insert(RowHandle *rh);
	virtual void remove(RowHandle *rh);
	virtual void aggregateBefore(const RhSet &rows, const RhSet &already);
	virtual void aggregateAfter(Aggregator::AggOp aggop, const RhSet &rows, const RhSet &future);
	virtual bool collapse(const RhSet &replaced);
	virtual Index *findNested(const RowHandle *what, int nestPos) const;

protected:
	// A helper function splitting a row handle set by groups.
	// @param rows - set to split
	// @param dest - destination map that gets populated 
	//        (if not empty then added to)
	void splitRhSet(const RhSet &rows, SplitMap &dest);

	Set data_; // the data store
	Autoref<const HashedIndexType> type_; // type of this index
	Less *less_; // the comparator object, owned by the type
};

}; // BICEPS_NS

#endif // __Biceps_HashedNestedIndex_h__
