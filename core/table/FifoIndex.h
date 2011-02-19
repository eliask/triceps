//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple FIFO storage.

#ifndef __Biceps_FifoIndex_h__
#define __Biceps_FifoIndex_h__

#include <table/Index.h>
#include <type/FifoIndexType.h>

namespace BICEPS_NS {

class FifoIndexType;
class RowType;

class FifoIndex: public Index
{
	friend class FifoIndexType;
public:
	// @param tabtype - type of table where this index belongs
	// @param table - the actual table where this index belongs
	// @param mytype - type that created this index
	FifoIndex(const TableType *tabtype, Table *table, const FifoIndexType *mytype);
	~FifoIndex();

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
	virtual bool collapse(const RhSet &replaced);
	virtual Index *findNested(const RowHandle *what, int nestPos) const;

protected:
	typedef FifoIndexType::RhSection RhSection;

	// Get the section in the row handle
	RhSection *getSection(const RowHandle *rh) const
	{
		return type_->getSection(rh);
	}

	Autoref<const FifoIndexType> type_; // type of this index
	RowHandle *first_; // first element in the list
	RowHandle *last_; // last element in the list
	size_t size_; // the current size of the list
};

}; // BICEPS_NS

#endif // __Biceps_FifoIndex_h__
