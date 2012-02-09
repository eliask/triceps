//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that implements a unique primary key with an unpredictable order.

#ifndef __Triceps_HashedIndexType_h__
#define __Triceps_HashedIndexType_h__

#include <type/IndexType.h>
#include <common/Hash.h>

namespace TRICEPS_NS {

class RowType;

class HashedIndexType : public IndexType
{
public:
	// Keeps a reference of key. If key is not specified, it
	// must be set later, before initialization.
	HashedIndexType(NameSet *key = NULL);
	// Constructors duplicated as make() for syntactically better usage.
	static HashedIndexType *make(NameSet *key = NULL)
	{
		return new HashedIndexType(key);
	}
	

	// Set tke key later (until initialized).
	// Keeps a reference of key. Calling setKey() after the key has
	// been already set is wrong and will cause a memory leak.
	HashedIndexType *setKey(NameSet *key);

	// from Type
	virtual bool equals(const Type *t) const;
	virtual bool match(const Type *t) const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

	// from IndexType
	virtual const_Onceref<NameSet> getKey() const;
	virtual IndexType *copy() const;
	virtual void initialize();
	virtual Index *makeIndex(const TableType *tabtype, Table *table) const;
	virtual void initRowHandleSection(RowHandle *rh) const;
	virtual void clearRowHandleSection(RowHandle *rh) const;
	virtual void copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const;

protected:
	// index instance interface
	friend class HashedIndex;
	friend class HashedNestedIndex;

	struct RhSection;
	
	// Comparator class for the row objects
	class Less : public Starget
	{
	public:
		Less(const RowType *rt, intptr_t rhOffset, const vector<int32_t> &keyFld);

		bool operator() (const RowHandle *r1, const RowHandle *r2) const;

		// Calculate and remember the hash value for a row.
		// This is not part of the comparator as such but just a
		// convenient place to put this computation.
		void initHash(RowHandle *rh);

		// Get the section in the row handle
		RhSection *getSection(const RowHandle *rh) const
		{
			return rh->get<RhSection>(rhOffset_);
		}

	protected:
		const vector<int32_t> &keyFld_; // indexes of key fields in the record
		Autoref<const RowType> rt_;
		intptr_t rhOffset_; // offset of this index's data in table's row handle

	private:
		Less();
	};

	// not set of Autoref<RowHandle> because the row is owned by the whole table once,
	// not by each index; this also improves the performance a lot
	typedef set<RowHandle *, Less> Set; // storage for the records
	typedef set<GroupHandle *, Less> NestedSet; // storage for the nested groups

	// section in the RowHandle, placed at rhOffset_
	struct RhSection {
		void *operator new(size_t size, void *where) // placement
		{
			return where;
		}

		Set::iterator iter_; // location of this handle in the set
		Hash::Value hash_; // for quicker comparison
	};

protected:
	// used by copy()
	HashedIndexType(const HashedIndexType &orig);

	RhSection *getSection(const RowHandle *rh) const
	{
		return rh->get<RhSection>(rhOffset_);
	}

	// can be used only if the row is known to be in the table
	Set::iterator getIter(const RowHandle *rh) const
	{
		return rh->get<RhSection>(rhOffset_)->iter_;
	}
	
	// remember the iterator of the row in the table
	// XXX constness of row handle is wrong here
	void setIter(const RowHandle *rh, const Set::iterator &iter) const
	{
		rh->get<RhSection>(rhOffset_)->iter_ = iter;
	}

protected:
	Autoref<NameSet> key_;
	intptr_t rhOffset_; // offset of this index's data in table's row handle
	vector<int32_t> keyFld_; // indexes of key fields in the record
	Autoref<Less> less_;
};

}; // TRICEPS_NS

#endif // __Triceps_HashedIndexType_h__
