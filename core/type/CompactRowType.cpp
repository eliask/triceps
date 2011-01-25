//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Row type that operates on CompactRow internal representation.

#include <string.h>
#include <type/CompactRowType.h>

namespace BICEPS_NS {

CompactRowType::CompactRowType(const FieldVec &fields) :
	RowType(fields)
{ }

CompactRowType::CompactRowType(const RowType &proto) :
	RowType(proto)
{ }

CompactRowType::CompactRowType(const RowType *proto) :
	RowType(*proto)
{ }

CompactRowType::~CompactRowType()
{ }

RowType *CompactRowType::newSameFormat(const FieldVec &fields) const
{
	return new CompactRowType(fields);
}

bool CompactRowType::isFieldNull(const Row *row, int nf) const
{
	return static_cast<const CompactRow *>(row)->isFieldNull(nf);
}

bool CompactRowType::getField(const Row *row, int nf, const char *&ptr, intptr_t &len) const
{
	const CompactRow *cr = static_cast<const CompactRow *>(row);
	ptr = cr->getFieldPtr(nf);
	len = cr->getFieldLen(nf);
	return !cr->isFieldNull(nf);
}

Onceref<Row> CompactRowType::makeRow(FdataVec &data) const
{
	int i;
	int n = (int)fields_.size();

	if ((int)data.size() < n)
		fillFdata(data, n);
	
	// calculate the length
	intptr_t paylen = 0;
	for (i = 0; i < n; i++) {
		if (data[i].notNull_)
			paylen += data[i].len_;
	}
	CompactRow *row = new (CompactRow::variableLen(n, paylen)) CompactRow;
	
	// copy in the data from the main data entries
	intptr_t off = CompactRow::payloadOffset(n);
	char *to = row->payloadPtrW(n);
	for (i = 0; i < n; i++) {
		if (data[i].notNull_) {
			row->off_[i] = off;
			intptr_t len = data[i].len_;
			const char *d = data[i].data_;
			if (d == NULL) {
				memset(to, 0, len);
			} else {
				memcpy(to, d, len);
			}
			off += len;
			to += len;
		} else {
			row->off_[i] = (off | CompactRow::NULLMASK);
		}
	}
	row->off_[i] = off; // past last field

	// fill the overrides
	int nd = (int)data.size();
	for (i = n; i < nd; i++) {
		int f = data[i].nf_;
		if (f >= n)
			continue; // wrong field?
		off = data[i].off_;
		intptr_t len = data[i].len_;
		const char *d = data[i].data_;
		if (off < 0 || len <= 0 || d == NULL || off + len > row->getFieldLen(f))
			continue;
		memcpy(row->getFieldPtrW(f) + off, d, len);
	}

	return row;
}

}; // BICEPS_NS
