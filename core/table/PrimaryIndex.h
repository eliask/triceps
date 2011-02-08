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
	struct RhSection;

	// Comparator class for the row objects
	class Less {
	public:
		Less(const RowType *rt, intptr_t rhOffset, const vector<int32_t> &keyFld);

		bool operator() (const RowHandle *r1, const RowHandle *r2) const;

		// Calculate and remember the hash value for a row.
		// This is not part of the comparator as such but just a
		// convenient place to put this computation.
		void initHash(RowHandle *rh);

		// Get the section in the row handle
		RhSection *getSection(const RowHandle *rh) 
		{
			return rh->get<RhSection>(rhOffset_);
		}

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
	virtual RowHandle *begin() const;
	virtual RowHandle *next(RowHandle *cur) const;
	virtual RowHandle *nextGroup(RowHandle *cur) const;
	virtual RowHandle *find(RowHandle *what) const;
	virtual void initRowHandle(RowHandle *rh) const;
	virtual void clearRowHandle(RowHandle *rh) const;
	virtual bool replacementPolicy(RowHandle *rh, RhSet &replaced) const;
	virtual void insert(RowHandle *rh);
	virtual void remove(RowHandle *rh);

protected:
	// not set of Autoref<RowHandle> because the row is owned by the whole table once,
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
