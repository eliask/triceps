//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The reference with counting.

#ifndef __Biceps_Autoref_h__
#define __Biceps_Autoref_h__

#include <common/Conf.h>

namespace BICEPS_NS {

// The reference to a ref-counted object.
// The idea here is that the referenced object doesn't have to be virtual.
// It might be if it chooses so, but doesn't have to be.
// So the operations to increase and decrease the reference counts
// are done purely by name, from a template.
//
// The expected target's interface is:
//   incref(); - increase the ref count, the return type doesn't really matter
//   int decref(); - decrease the ref count and return the value. 
//     If returned <= 0, the reference will destroy the object.
//     decref() itself must NOT destroy the object.
// If the target is a const class, the incref and decref methods
// must be also declared const and their internal reference be still mutable.
// Also, the assignment and copy constructor of the target class must NOT
// copy the reference counter.

template <typename Target>
class Autoref
{
public:
	typedef Target *Ptr;

	Autoref() :
		ref_(0)
	{ }

	// Constructor from a plain pointer.
	// @param t - pointer to target, may be NULL
	Autoref(Target *t) :
		ref_(t)
	{
		if (t)
			t->incref();
	}

	// Constructor from another Autoref
	Autoref(const Autoref &ar) :
		ref_(ar.ref_)
	{
		if (ref_)
			ref_->incref();
	}

	// This is for the automatic casts of the content pointer types
	template <typename OtherTarget>
	Autoref(const Autoref<OtherTarget> &ar) :
		ref_(ar.get())
	{
		if (ref_)
			ref_->incref();
	}

	~Autoref()
	{
		drop();
	}

	// A dereference
	Target &operator*() const
	{
		return *ref_; // works fine even with NULL (until that thing gets dereferenced)
	}

	Target *operator->() const
	{
		return ref_; // works fine even with NULL (until that thing gets dereferenced)
	}

	// Getting the internal pointer
	Target *get() const
	{
		return ref_;
	}

	// same but transparently, as a type conversion
	operator Ptr() const
	{
		return ref_;
	}

	// A convenience comparison to NULL
	bool isNull() const
	{
		return (ref_ == 0);
	}

	Autoref &operator=(const Autoref &ar)
	{
		if (&ar != this) { // assigning to itself is a null-op that might cause a mess
			drop();
			Target *r = ar.ref_;
			ref_ = r;
			if (r)
				r->incref();
		}
		return *this;
	}
	
	// This is for the automatic casts of the content pointer types
	template <typename OtherTarget>
	Autoref &operator=(const Autoref<OtherTarget> &ar)
	{
		if ((void *)&ar != (void *)this) { // assigning to itself is a null-op that might cause a mess
			drop();
			Target *r = ar.get();
			ref_ = r;
			if (r)
				r->incref();
		}
		return *this;
	}

	bool operator==(const Autoref &ar)
	{
		return (ref_ == ar.ref_);
	}
	bool operator!=(const Autoref &ar)
	{
		return (ref_ != ar.ref_);
	}

	// This is for the automatic casts of the content pointer types
	template <typename OtherTarget>
	bool operator==(const Autoref<OtherTarget> &ar)
	{
		return (ref_ == ar.get());
	}
	template <typename OtherTarget>
	bool operator!=(const Autoref<OtherTarget> &ar)
	{
		return (ref_ != ar.get());
	}

protected:
	// Drop the current reference
	inline void drop()
	{
		Target *r = ref_;
		if (r)
			if (r->decref() <= 0)
				delete r;
	}

	Target *ref_; // the actual pointer
};

// This is a placeholder for now. In the future it may become an optimized
// version to be used when an auto-referenced value needs to be passed
// once, such as when returning a newly allocated value from a function,
// and then this reference just moved to autoref. It's kind_of like STL autoptr.
// But for now just default to the same as Autoref.

template <typename Target>
class Onceref : public Autoref<Target>
{
public:
	Onceref()
	{ }

	Onceref(Target *t) :
		Autoref<Target>(t)
	{ }

	Onceref(const Autoref<Target> &ar) :
		Autoref<Target>(ar)
	{ }
};

}; // BICEPS_NS

#endif // __Biceps_Autoref_h__
