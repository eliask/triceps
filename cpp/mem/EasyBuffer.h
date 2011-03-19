//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A reference-counted byte buffer

#ifndef __Biceps_EasyBuffer_h__
#define __Biceps_EasyBuffer_h__

#include <common/Common.h>
#include <mem/Starget.h>

namespace BICEPS_NS {

// There is a frequent case of temporary variable-sized byte buffers
// used for construction of rows and such. This takes care of them.
class EasyBuffer : public Starget
{
public:
	
	// @param basic - provided by C++ compiler, size of the basic structure
	// @param variable - actual size for data_[]
	static void *operator new(size_t basic, intptr_t variable)
	{
		return malloc((intptr_t)basic + variable - 1); // -1 accounts for the existing one byte
	}
	static void operator delete(void *ptr)
	{
		free(ptr);
	}

	int size_; // the size of the buffer can be remembered here if desired.
	char data_[1];
};

}; // BICEPS_NS

#endif // __Biceps_EasyBuffer_h__
