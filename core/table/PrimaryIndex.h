//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key.

#ifndef __Biceps_PrimaryIndex_h__
#define __Biceps_PrimaryIndex_h__

#include <table/Index.h>
#include <table/RowHandle.h>
#include <common/Hash.h>

namespace BICEPS_NS {

class PrimaryIndexType;
class RowType;

class PrimaryIndex: public Index
{
	friend class PrimaryIndexType;
protected:

	// Comparator class for the row objects
	class Less {
	public:
		Less(const RowType *rt, intptr_t rhOffset, const vector<int32_t> &keyFld);

		bool operator() (const RowHandle *r1, const RowHandle *r2) const;
	protected:
		vector<int32_t> keyFld_; // indexes of key fields in the record
		Autoref<const RowType> rt_;
		intptr_t rhOffset_; // offset of this index's data in table's row handle

	private:
		Less();
	};

public:
	// @param tabtype - type of table where this index belongs
	// @param table - the actual table where this index belongs
	// @param mytype - type that created this index
	// @param lessop - less functor class for the key, this index assumes is ownership
	PrimaryIndex(const TableType *tabtype, Table *table, const PrimaryIndexType *mytype, Less *lessop);
	~PrimaryIndex();

	// from Index
	virtual void clearData();
	virtual const IndexType *getType() const;

protected:
	// not Autoref<RowHandle> because the row is owned by the whole table once,
	// not by each index; this also improves the performance a lot
	typedef set<RowHandle *, Less> Set; // storage for the records

	// section in the RowHandle, placed at rhOffset_
	struct RhSection {
		Set::iterator iter_; // location of this handle in the set
		Hash::Value hash_; // for quicker comparison
	};

	Set data_; // the data store
	Autoref<const PrimaryIndexType> type_; // type of this index
	Less *less_; // the comparator object
};

}; // BICEPS_NS

#endif // __Biceps_PrimaryIndex_h__
