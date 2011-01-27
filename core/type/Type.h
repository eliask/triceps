//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The general type definition.

#ifndef __Biceps_Type_h__
#define __Biceps_Type_h__

#include <mem/Mtarget.h>
#include <common/Common.h>

namespace BICEPS_NS {

class SimpleType;

// This is a base class for both the simple and complex types.
// Note that the complex types should normally refer to their component
// types as const, sinc ethey have no business changing these components.
class Type : public Mtarget
{
public:
	// The identification of types that allows a switch on the implementation,
	// casting from the base class back to the subclasses
	enum TypeId {
		TT_VOID, // no value
		TT_UINT8, // unsigned 8-bit integer (byte)
		TT_INT32, // 32-bit integer
		TT_INT64,
		TT_FLOAT64, // 64-bit floating-point, what C calls "double"
		TT_STRING, // a string: a special kind of byte array
		TT_ROW, // a row of a table
		// add the new types here
		TT_LAST_MARKER // for range checks, goes after all the real types
	};

	// @param simple - flag: this is a simple type (must be consistent with typeid)
	// @param id - 
	Type(bool simple, TypeId id) :
		typeId_(id),
		simple_(simple) 
	{ }
		
	virtual ~Type()
	{ }

	// @return - true if this is a simple type
	bool isSimple() const
	{
		return simple_;
	}

	// @return - the id value of this type
	bool getTypeId() const
	{
		return typeId_;
	}

	// A convenience function to find a simple type by name (including void).
	// @param name - name of the type
	// @return - the type reference (one of r_*) or NULL if not found
	static const Onceref<const SimpleType> findSimpleType(const char *name);

	// Get the errors collected when parsing this type
	// @return - errors reference, may be NULL
	virtual Erref getErrors() const = 0;

	// The types can be equal in one of 3 ways, in order or decreasting exactness:
	// 1. Exactly the same Type object.
	//    Compary the pointers.
	// 2. The contents, including the subtypes and the names of field matches exactly.
	//    The equals() and operator==()
	// 3. The names of fields may be different.
	//    The method match()
	bool operator==(const Type &t) const
	{
		return equals(&t);
	}
	// normally types are referred by autoref, so pointers are more convenient than references
	virtual bool equals(const Type *t) const
	{
		if (this == t) // a shortcut
			return true;
		if (typeId_ != t->typeId_)
			return false;
		// the rest is up to subclasses
		return true;
	}
	virtual bool match(const Type *t) const
	{
		// most types don't have any field names, so it ends up the same as ==,
		// the rest can redefine this method
		return equals(t);
	}

public:
	// the global copies of the simple types that can be reused everywhere
	static Autoref<const SimpleType> r_void;
	static Autoref<const SimpleType> r_uint8;
	static Autoref<const SimpleType> r_int32;
	static Autoref<const SimpleType> r_int64;
	static Autoref<const SimpleType> r_float64;
	static Autoref<const SimpleType> r_string;

protected:
	enum TypeId typeId_; // allows to do switching and casting on it
	bool simple_; // flag: this is a simple type

private:
	Type();
};

}; // BICEPS_NS

#endif // __Biceps_Type_h__
