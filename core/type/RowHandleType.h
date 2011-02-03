//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The type building for RowHandles.

#ifndef __Biceps_RowHandle_h__
#define __Biceps_RowHandle_h__

#include <type/Type.h>

namespace BICEPS_NS {

// This is metadata used for building a RowHandle out of sections
class RowHandleType : public Type
{
public:
	RowHandleType();
	RowHandleType(const RowHandleType &orig);

	// Factory for the new handles
	RowHandle *makeHandle() const
	{
		return new(size_) RowHandle;
	}

	// Get the payload size in this handle
	intptr_t getSize() const
	{
		return size_;
	}

	// Allocates an aligned area and returns its offset
	// @param amount - amount of data to allocate
	// @return - offset that can be used in RowHandle::get()
	intptr_t allocate(size_t amount);

	// from Type
	virtual Erref getErrors() const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

protected:
	intptr_t size_; // total size of payload accumulated
};

}; // BICEPS_NS

#endif // __Biceps_RowHandle_h__
