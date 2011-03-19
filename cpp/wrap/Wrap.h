//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Wrappers for handling of objects from interpreted languages.

#ifndef __Biceps_Wrap_h__
#define __Biceps_Wrap_h__

#include <type/AllTypes.h>
#include <sched/Unit.h>

namespace BICEPS_NS {

// for extra safety, add a magic in front of each wrapper

struct WrapMagic {
	char v_[8]; // 8 bytes to make a single 64-bit comparison

	bool operator!=(const WrapMagic &wm)
	{
		return (*(int64_t *)v_) != (*(int64_t *)wm.v_);
	}
};

template<const WrapMagic &magic, class Class>
class Wrap
{
public:
	Wrap(Onceref<Class> r) :
		magic_(magic),
		ref_(r)
	{ }

	// returns true if the magic value is bad
	bool badMagic()
	{
		return magic_ != magic;
	}

	Class *get() const
	{
		return ref_.get();
	}

	operator Class*() const
	{
		return ref_.get();
	}

public:
	WrapMagic magic_;
	Autoref<Class> ref_; // referenced value
private:
	Wrap();
};

extern WrapMagic magicWrapUnit;
typedef Wrap<magicWrapUnit, Unit> WrapUnit;

extern WrapMagic magicWrapRowType;
typedef Wrap<magicWrapUnit, RowType> WrapRowType;

// These are special cases because they combine a type and object
class WrapRow
{
public:
	WrapRow(RowType *t, Row *r) :
		magic_(classMagic_),
		r_(t, r)
	{ }

	WrapRow(const Rowref &r) :
		magic_(classMagic_),
		r_(r)
	{ }
	
	// returns true if the magic value is bad
	bool badMagic()
	{
		return magic_ != classMagic_;
	}

public:
	WrapMagic magic_;
	Rowref r_; // referenced row

	static WrapMagic classMagic_;
private:
	WrapRow();
};

}; // BICEPS_NS

#endif // __Biceps_Wrap_h__
