//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that simply keeps the records in the order entered.

#ifndef __Biceps_FifoIndexType_h__
#define __Biceps_FifoIndexType_h__

#include <type/IndexType.h>

namespace BICEPS_NS {

// It's not much of an index, simply keeping the records in a list.
// But it's useful fo rthings like storing the aggregation groups.
class FifoIndexType : public IndexType
{
public:
	// @param limit - the record count limit, or 0 for unlimited
	// @param jumping - flag: this is a jumping index, i.e. when the count limit is
	//        overfilled, all the current records will be flushed out. "Overfilled"
	//        mans that the flush will happen only on the insertion of the next
	//        record that would be pushing the size over the limit.
	FifoIndexType(size_t limit = 0, bool jumping = false);
	// Constructors duplicated as make() for syntactically better usage.
	static FifoIndexType *make(size_t limit = 0, bool jumping = false)
	{
		return new FifoIndexType(limit, jumping);
	}

	// from Type
	virtual bool equals(const Type *t) const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

	// from IndexType
	virtual IndexType *copy() const;
	virtual void initialize();
	virtual Index *makeIndex(const TableType *tabtype, Table *table) const;
	virtual void initRowHandleSection(RowHandle *rh) const;
	virtual void clearRowHandleSection(RowHandle *rh) const;
	virtual void copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const;

	size_t getLimit() const
	{
		return limit_;
	}

	bool isJumping() const
	{
		return jumping_;
	}

	// Set the limit later (only until initialized).
	FifoIndexType *setLimit(size_t limit);
	// Set the jumping flag later (only until initialized).
	FifoIndexType *setJumping(bool jumping);

protected:
	// interface for the index instances
	friend class FifoIndex;
	
	// section in the RowHandle, placed at rhOffset_
	struct RhSection {
		RowHandle *prev_; // previous in the list
		RowHandle *next_; // next in the list
	};

	intptr_t getRhOffset() const
	{
		return rhOffset_;
	}

	// Get the section in the row handle
	RhSection *getSection(const RowHandle *rh) const
	{
		return rh->get<RhSection>(rhOffset_);
	}

protected:
	// used by copy()
	FifoIndexType(const FifoIndexType &orig);

	intptr_t rhOffset_; // offset of this index's data in table's row handle
	size_t limit_; // 0 means unlimited
	bool jumping_; // flag: this is a jumping index
};

}; // BICEPS_NS

#endif // __Biceps_FifoIndexType_h__
