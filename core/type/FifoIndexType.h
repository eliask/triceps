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
	FifoIndexType(size_t limit = 0);

	// from Type
	virtual bool equals(const Type *t) const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

	// from IndexType
	virtual IndexType *copy() const;
	virtual void initialize(TableType *tabtype);
	virtual Index *makeIndex(const TableType *tabtype, Table *table) const;

	size_t getLimit() const
	{
		return limit_;
	}

	intptr_t getRhOffset() const
	{
		return rhOffset_;
	}

protected:
	// used by copy()
	FifoIndexType(const FifoIndexType &orig);

	intptr_t rhOffset_; // offset of this index's data in table's row handle
	size_t limit_;
};

}; // BICEPS_NS

#endif // __Biceps_FifoIndexType_h__
