//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key.

#ifndef __Triceps_HashedIndex_h__
#define __Triceps_HashedIndex_h__

#include <table/Index.h>
#include <type/HashedIndexType.h>

namespace TRICEPS_NS {

class RowType;

class HashedIndex: public Index
{
	friend class HashedIndexType;
	friend class TreeIndexType;

public:
	typedef TreeIndexType::Less Less;
	typedef TreeIndexType::Set Set;

	// @param tabtype - type of table where this index belongs
	// @param table - the actual table where this index belongs
	// @param mytype - type that created this index
	// @param lessop - less functor class for the key, this index assumes is ownership
	HashedIndex(const TableType *tabtype, Table *table, const HashedIndexType *mytype, Less *lessop);
	~HashedIndex();

	// from Index
	virtual void clearData();
	virtual const IndexType *getType() const;
	virtual RowHandle *begin() const;
	virtual RowHandle *next(const RowHandle *cur) const;
	virtual RowHandle *last() const;
	virtual const GroupHandle *nextGroup(const GroupHandle *cur) const;
	virtual const GroupHandle *beginGroup() const;
	virtual const GroupHandle *toGroup(const RowHandle *cur) const;
	virtual RowHandle *find(const RowHandle *what) const;
	virtual bool replacementPolicy(RowHandle *rh, RhSet &replaced);
	virtual void insert(RowHandle *rh);
	virtual void remove(RowHandle *rh);
	virtual void aggregateBefore(Tray *dest, const RhSet &rows, const RhSet &already, Tray *copyTray);
	virtual void aggregateAfter(Tray *dest, Aggregator::AggOp aggop, const RhSet &rows, const RhSet &future, Tray *copyTray);
	virtual bool collapse(Tray *dest, const RhSet &replaced, Tray *copyTray);
	virtual Index *findNested(const RowHandle *what, int nestPos) const;

protected:
	Set data_; // the data store
	Autoref<const HashedIndexType> type_; // type of this index
	Less *less_; // the comparator object, owned by the type
};

}; // TRICEPS_NS

#endif // __Triceps_HashedIndex_h__
