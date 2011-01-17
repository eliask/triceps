//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The general type definition.

namespace Biceps {

class Type
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
		simple_(simple), typeId_(id)
	{ }
		
	virtual ~Type()
	{ }

	// @return - true if this is a simple type
	bool isSimple()
	{
		return simple_;
	}

	// @return - the id value of this type
	bool getTypeId()
	{
		return typeId_;
	}

protected:
	enum TypeId typeId_; // allows to do switching and casting on it
	bool simple_; // flag: this is a simple type
};

}; // Biceps
