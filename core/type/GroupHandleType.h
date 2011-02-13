//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for constructing the group handles.

#ifndef __Biceps_GroupHandleType_h__
#define __Biceps_GroupHandleType_h__

#include <type/RowHandleType.h>
#include <table/GroupHandle.h>

namespace BICEPS_NS {

class GroupHandleType : public RowHandleType
{
public:
	GroupHandleType()
	{ }

	GroupHandleType(const RowHandleType &orig) :
		RowHandleType(orig)
	{ }
	
	// Factory for the new handles.
	// @param r - the row to refer, the caller must have it already incref-ed.
	GroupHandle *makeHandle(const Row *r) const
	{
		return new(size_) GroupHandle(r);
	}

};

}; // BICEPS_NS

#endif // __Biceps_GroupHandleType_h__
