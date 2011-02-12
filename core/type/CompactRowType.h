//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Row type that operates on CompactRow internal representation.

#ifndef __Biceps_CompactRowType_h__
#define __Biceps_CompactRowType_h__

#include <type/RowType.h>
#include <mem/CompactRow.h>

namespace BICEPS_NS {

class CompactRowType : public RowType
{
public:
	CompactRowType(const FieldVec &fields);
	CompactRowType(const RowType &proto);
	// a convenience, since we usually get pointers in Autoref
	CompactRowType(const RowType *proto);
	virtual ~CompactRowType();

	// from RowType
	virtual RowType *newSameFormat(const FieldVec &fields) const;
	virtual bool isFieldNull(const Row *row, int nf) const;
	virtual bool getField(const Row *row, int nf, const char *&ptr, intptr_t &len) const;
	virtual Row *makeRow(FdataVec &data_) const;
	virtual void destroyRow(Row *row) const;
	virtual void hexdumpRow(string &dest, const Row *row, const string &indent="") const;
	virtual bool equalRows(const Row *row1, const Row *row2) const;
};

}; // BICEPS_NS

#endif // __Biceps_CompactRowType_h__
