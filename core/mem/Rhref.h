//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Counted reference to a RowHandle.

#ifndef __Biceps_Rhref_h__
#define __Biceps_Rhref_h__

#include <table/Table.h>

namespace BICEPS_NS {

// The row handle needs its private kind of autoref because it's
// not virtual, so the reference would have to remember the right
// table type to provide the imitation of virtuality.
// (similar to the Row class)

class Rhref
{
public:
	typedef RowHandle *RowHandlePtr;

	Rhref() :
		rh_(NULL)
	{ }

	// Constructor from a plain pointer.
	// @param t - the table where the row handle belongs (may be NULL if row is NULL)
	// @param r - the row handle, may be NULL
	Rhref(Table *t, RowHandle *r) :
		table_(t), 
		rh_(r)
	{
		if (r)
			r->incref();
	}

	// Constructor from another Rhref
	Rhref(const Rhref &ar) :
		table_(ar.table_),
		rh_(ar.rh_)
	{
		if (rh_)
			rh_->incref();
	}

	~Rhref()
	{
		drop();
	}

	// A dereference
	RowHandle &operator*() const
	{
		return *rh_; // works fine even with NULL (until that thing gets dereferenced)
	}

	RowHandle *operator->() const
	{
		return rh_; // works fine even with NULL (until that thing gets dereferenced)
	}

	// Getting the internal pointer
	RowHandle *get() const
	{
		return rh_;
	}
	Table *getTable() const // should this return Autoref?
	{
		return table_.get();
	}

	// same but transparently, as a type conversion
	operator RowHandlePtr() const
	{
		return rh_;
	}

	// A convenience comparison to NULL
	bool isNull() const
	{
		return (rh_ == 0);
	}

	Rhref &operator=(const Rhref &ar)
	{
		if (&ar != this) { // assigning to itself is a null-op that might cause a mess
			drop();
			table_ = ar.table_;
			RowHandle *r = ar.rh_;
			rh_ = r;
			if (r)
				r->incref();
		}
		return *this;
	}
	// for multiple arguments, have to use a method...
	void assign(Table *t, RowHandle *r)
	{
		drop();
		table_ = t;
		rh_ = r;
		if (r)
			r->incref();
	}
	
	bool operator==(const Rhref &ar)
	{
		return (rh_ == ar.rh_);
	}
	bool operator!=(const Rhref &ar)
	{
		return (rh_ != ar.rh_);
	}

protected:
	// Drop the current reference
	inline void drop()
	{
		RowHandle *r = rh_;
		if (r)
			if (r->decref() <= 0)
				table_->destroyRowHandle(r);
		// don't decrease the table ref, likely the same table will be assigned again,
		// and it will save on decreasing/increaing the table reference
	}

protected:
	Autoref<Table> table_;
	RowHandle *rh_;
};

}; // BICEPS_NS

#endif // __Biceps_Rhref_h__
