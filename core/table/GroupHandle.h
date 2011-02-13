//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Handle to store groups in the non-leaf indexes.

#ifndef __Biceps_GroupHandle_h__
#define __Biceps_GroupHandle_h__

#include <table/RowHandle.h>

namespace BICEPS_NS {

class GroupHandle: public RowHandle
{
public:
	// uses the new() from RowHandle to pass the actual size
	
	GroupHandle(const Row *row) : // Table knows to incref() the row before this
		RowHandle(row)
	{
		flags_ |= F_GROUP;
	}
};

}; // BICEPS_NS

#endif // __Biceps_GroupHandle_h__
