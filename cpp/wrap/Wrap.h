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
#include <table/Table.h>
#include <mem/Rhref.h>

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

// A template for wrapper that needs to know the identity of the parent
// object (although in C++ that parent object is not strictly required for access).
template<const WrapMagic &magic, class ParentClass, class ValueClass>
class WrapIdent
{
public:
	WrapIdent(ParentClass *p, ValueClass *r) :
		magic_(magic),
		parent_(p),
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

	ParentClass *getParent() const
	{
		return ref_.get();
	}

	// returns true if the parent doesn't match
	bool badParent(ParentClass *p)
	{
		return (parent_.get() != p);
	}

public:
	WrapMagic magic_;
	Autoref<ParentClass> parent_; // referenced parent
	Autoref<ValueClass> ref_; // referenced value

	static WrapMagic classMagic_;
private:
	WrapIdent();
};

#define DEFINE_WRAP(what) \
	extern WrapMagic magicWrap##what; \
	typedef Wrap<magicWrap##what, what> Wrap##what

#define DEFINE_WRAP2(typewhat, refwhat, what) \
	extern WrapMagic magicWrap##what; \
	typedef Wrap2<magicWrap##what, typewhat, what, refwhat> Wrap##what

#define DEFINE_WRAP_IDENT(typewhat, what) \
	extern WrapMagic magicWrap##what; \
	typedef WrapIdent<magicWrap##what, typewhat, what> Wrap##what

DEFINE_WRAP(RowType);
DEFINE_WRAP2(RowType, Rowref, Row);
DEFINE_WRAP(IndexType);
DEFINE_WRAP(TableType);

DEFINE_WRAP(Unit);
DEFINE_WRAP_IDENT(Unit, Tray);
DEFINE_WRAP(Label);
DEFINE_WRAP(Gadget);
DEFINE_WRAP(Rowop);

DEFINE_WRAP(Table);
DEFINE_WRAP(Index);
DEFINE_WRAP2(Table, Rhref, RowHandle);

#undef DEFINE_WRAP
#undef DEFINE_WRAP2
#undef DEFINE_WRAP_IDENT

}; // BICEPS_NS

#endif // __Biceps_Wrap_h__
