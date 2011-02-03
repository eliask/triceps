//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The common interface for indexes.

#ifndef __Biceps_Index_h__
#define __Biceps_Index_h__

#include <common/Common.h>

namespace BICEPS_NS {

class IndexType;

class Index
{
public:
	virtual ~Index();

	// Clear the contents of the index. The actual RowHandles are guaranteed
	// to be still held by the table, so the cleaning can be fast.
	virtual void clear() = 0;
};

}; // BICEPS_NS

#endif // __Biceps_Index_h__
