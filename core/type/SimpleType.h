//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Common subclass for the simple types

#ifndef __Biceps_SimpleType_h__
#define __Biceps_SimpleType_h__

#include <type/Type.h>

namespace BICEPS_NS {

// Later, when there will be own language, these definitions may become
// more complex and be split into their separate files.

class SimpleType : public Type
{
public:
	SimpleType(TypeId id, int size) :
		Type(true, id),
		size_(size)
	{ }

	// get the size of a basic element
	int getSize() const
	{
		return size_;
	}

protected:
	int size_; // size of the basic element of this type

private:
	SimpleType();
};

}; // BICEPS_NS

#endif // __Biceps_SimpleType_h__

