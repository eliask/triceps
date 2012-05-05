//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A scope-based helper class to set and clear the busy mark.

#ifndef __Triceps_Proto_h__
#define __Triceps_Proto_h__

#include <common/Common.h>

namespace TRICEPS_NS {

class BusyMark
{
public:
	// @param markp - mark to set now and clear on leaving the scope
	BusyMark(bool &mark) :
		markp_(&mark)
	{ 
		mark = true; // mark busy
	}

	~BusyMark()
	{
		*markp_ = false;
	}

protected:
	bool *markp_;

private:
	BusyMark(); // no default constructor
};

}; // TRICEPS_NS

#endif // __Triceps_Proto_h__

