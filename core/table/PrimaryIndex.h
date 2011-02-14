//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key.

#ifndef __Biceps_PrimaryIndex_h__
#define __Biceps_PrimaryIndex_h__

#include <table/Index.h>
#include <type/PrimaryIndexType.h>

namespace BICEPS_NS {

class PrimaryIndexType;
class RowType;

class PrimaryIndex: public Index
{
	friend class PrimaryIndexType;

public:
	typedef PrimaryIndexType::Less Less;
	typedef PrimaryIndexType::RhSection RhSection;
	typedef PrimaryIndexType::Set Set;

	// @param tabtype - type of table where this index belongs
	// @param table - the actual table where this index belongs
	// @param mytype - type that created this index
	// @param lessop - less functor class for the key, this index assumes is ownership
	PrimaryIndex(const TableType *tabtype, Table *table, const PrimaryIndexType *mytype, Less *lessop);
	~PrimaryIndex();

	// from Index
	virtual void clearData();
	virtual const IndexType *getType() const;
	virtual RowHandle *begin() const;
	virtual RowHandle *next(RowHandle *cur) const;
	virtual RowHandle *nextGroup(RowHandle *cur) const;
	virtual RowHandle *find(RowHandle *what) const;
	virtual bool replacementPolicy(RowHandle *rh, RhSet &replaced) const;
	virtual void insert(RowHandle *rh);
	virtual void remove(RowHandle *rh);
	virtual Index *findNested(RowHandle *what, int nestPos) const;

protected:
	Set data_; // the data store
	Autoref<const PrimaryIndexType> type_; // type of this index
	Less *less_; // the comparator object, owned by the type
};

}; // BICEPS_NS

#endif // __Biceps_PrimaryIndex_h__
