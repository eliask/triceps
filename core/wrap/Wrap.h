//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Wrappers for handling of objects from interpreted languages.

#ifndef __Biceps_Wrap_h__
#define __Biceps_Wrap_h__

#include <type/AllTypes.h>

namespace BICEPS_NS {

// for extra safety, add a magic in front of each wrapper

struct WrapMagic {
	char v_[8]; // 8 bytes to make a single 64-bit comparison

	bool operator!=(const WrapMagic &wm)
	{
		return (*(int64_t *)v_) != (*(int64_t *)wm.v_);
	}
};

class WrapRowType
{
public:
	WrapRowType(Onceref<RowType> t) :
		magic_(classMagic_),
		t_(t)
	{ }

	// returns true if the magic value is bad
	bool badMagic()
	{
		return magic_ != classMagic_;
	}

public:
	WrapMagic magic_;
	Autoref<RowType> t_; // referenced type

	static WrapMagic classMagic_;
private:
	WrapRowType();
};

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
