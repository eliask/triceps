//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A special service index type that represents the root of the index type
// tree in a table type.

#ifndef __Biceps_RootIndexType_h__
#define __Biceps_RootIndexType_h__

#include <type/IndexType.h>

namespace BICEPS_NS {

class RootIndexType : public IndexType
{
public:
	~RootIndexType();

	// from Type
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

	// from IndexType
	virtual IndexType *copy() const;
	virtual void initialize(TableType *tabtype);
	virtual Index *makeIndex(const TableType *tabtype, Table *table) const;
	virtual void initRowHandleSection(RowHandle *rh) const;
	virtual void clearRowHandleSection(RowHandle *rh) const;
	virtual void copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const;

protected:
	friend class TableType;

	// only the Table may create it
	RootIndexType();

	// used by copy()
	RootIndexType(const RootIndexType &orig);
};

}; // BICEPS_NS

#endif // __Biceps_RootIndexType_h__
