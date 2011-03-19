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

// A template for wrapper with a simple single Autoref
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

// A template for wrapper with a separate class the knows how
// to access the main class (Row, RowHandle and such)
template<const WrapMagic &magic, class TypeClass, class ValueClass, class RefClass>
class Wrap2
{
public:
	Wrap2(TypeClass *t, ValueClass *r) :
		magic_(magic),
		ref_(t, r)
	{ }

	Wrap2(const RefClass &r) :
		magic_(magic),
		ref_(r)
	{ }
	
	// returns true if the magic value is bad
	bool badMagic()
	{
		return magic_ != magic;
	}

	ValueClass *get() const
	{
		return ref_.get();
	}

	operator ValueClass*() const
	{
		return ref_.get();
	}

public:
	WrapMagic magic_;
	RefClass ref_; // referenced value

	static WrapMagic classMagic_;
private:
	Wrap2();
};

extern WrapMagic magicWrapUnit;
typedef Wrap<magicWrapUnit, Unit> WrapUnit;

extern WrapMagic magicWrapRowType;
typedef Wrap<magicWrapUnit, RowType> WrapRowType;

extern WrapMagic magicWrapRow;
typedef Wrap2<magicWrapUnit, RowType, Row, Rowref> WrapRow;


}; // BICEPS_NS

#endif // __Biceps_Wrap_h__
