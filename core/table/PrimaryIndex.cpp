//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key.

#include <table/PrimaryIndex.h>
#include <type/PrimaryIndexType.h>
#include <type/RowType.h>
#include <string.h>

namespace BICEPS_NS {

//////////////////////////// PrimaryIndex::Less  /////////////////////////

PrimaryIndex::Less::Less(const RowType *rt, intptr_t rhOffset, const vector<int32_t> &keyFld)  :
	keyFld_(keyFld),
	rt_(rt),
	rhOffset_(rhOffset)
{ }

bool PrimaryIndex::Less::operator() (const RowHandle *r1, const RowHandle *r2) const 
{
	RhSection *rs1 = r1->get<RhSection>(rhOffset_);
	RhSection *rs2 = r2->get<RhSection>(rhOffset_);

	{
		Hash::SValue hdf= (Hash::SValue)(rs1->hash_ - rs2->hash_);
		if (hdf < 0)
			return true;
		if (hdf > 0)
			return false;
	}

	// otherwise do the full comparison
	int nf = keyFld_.size();
	for (int i = 0; i < nf; i++) {
		int idx = keyFld_[i];
		bool notNull1, notNull2;
		const char *v1, *v2;
		intptr_t len1, len2;

		notNull1 = rt_->getField(r1->getRow(), idx, v1, len1);
		notNull2 = rt_->getField(r2->getRow(), idx, v2, len2);

		// another shortcut
		if (len1 < len2)
			return true;
		if (len1 > len2)
			return false;

		if (len1 != 0) {
			int df = memcmp(v1, v2, len1);
			if (df < 0)
				return true;
			if (df > 0)
				return false;
		}

		// finally check for nulls if all else equal
		if (!notNull1){
			if (notNull2)
				return true;
		} else {
			if (!notNull2)
				return false;
		}
	}

	return false; // gets here only on equal values
}

//////////////////////////// PrimaryIndex /////////////////////////

PrimaryIndex::PrimaryIndex(const TableType *tabtype, Table *table, const PrimaryIndexType *mytype, Less *lessop) :
	Index(tabtype, table),
	data_(*lessop),
	type_(mytype),
	less_(lessop)
{ }

PrimaryIndex::~PrimaryIndex()
{
	data_.clear();
	delete less_;
}

void PrimaryIndex::clearData()
{
	data_.clear();
}

const IndexType *PrimaryIndex::getType() const
{
	return type_;
}
}; // BICEPS_NS
