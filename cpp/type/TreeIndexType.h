//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The common part of implementation for the indexes that rely on the tree
// search.

#ifndef __Triceps_TreeIndexType_h__
#define __Triceps_TreeIndexType_h__

#include <type/IndexType.h>

namespace TRICEPS_NS {

class RowType;

class TreeIndexType : public IndexType
{
	// this class is intended to be used by subclasses only
protected:
	TreeIndexType(IndexId it):
		IndexType(it)
	{ }
	
	// used by copy()
	// The copied index type is alway uninitialized, so no point
	// in copying the contents of the fields, they will be
	// set by the subclass on initialization.
	TreeIndexType(const TreeIndexType &orig) :
		IndexType(orig)
	{ }

public:
	// index instance interface: the part made public for the sorted indexes
	
	// Comparator base class for the row objects
	class Less : public Mtarget
	{
	public:
		// Creates and keeps the reference to rt.
		Less(const RowType *rt) :
			rt_(rt)
		{ }

		virtual ~Less();

		// To be redefined by the concrete comparators. 
		virtual bool operator() (const RowHandle *r1, const RowHandle *r2) const = 0;

	protected:
		Autoref<const RowType> rt_;

	private:
		Less();
	};

protected:
	// index instance interface
	friend class TreeIndex;
	friend class TreeNestedIndex;

	// Not a set of Autoref<RowHandle> because the row is owned by the whole table once,
	// not by each index; this also improves the performance a lot.
	// Also important to use a reference to Less, not Less itself, because 
	// actually the subclasses of Less will be used.
	typedef set<RowHandle *, Less &> Set; // storage for the records
	typedef set<GroupHandle *, Less &> NestedSet; // storage for the nested groups

public:
	// again public for the sorted index comparators
	// section in the RowHandle, placed at rhOffset_
	struct BasicRhSection {
		void *operator new(size_t size, void *where) // placement
		{
			return where;
		}

		Set::iterator iter_; // location of this handle in the set
	};

protected:
	// not used any more except for debugging
	BasicRhSection *getSection(const RowHandle *rh) const
	{
		return rh->get<BasicRhSection>(rhOffset_);
	}

	// can be used only if the row is known to be in the table
	Set::iterator getIter(const RowHandle *rh) const
	{
		return rh->get<BasicRhSection>(rhOffset_)->iter_;
	}
	
	// remember the iterator of the row in the table
	void setIter(RowHandle *rh, const Set::iterator &iter) const
	{
		rh->get<BasicRhSection>(rhOffset_)->iter_ = iter;
	}

protected:
	// the fields get set by the subclasses in initialize()
	intptr_t rhOffset_; // offset of this index's data in table's row handle
};

}; // TRICEPS_NS

#endif // __Triceps_TreeIndexType_h__
