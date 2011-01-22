//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The row type definition.

#ifndef __Biceps_RowType_h__
#define __Biceps_RowType_h__

#include <type/SimpleType.h>
#include <common/Common.h>
#include <mem/Autoref.h>

namespace BICEPS_NS {

// Type of a record that can be stored in a Window.
class RowType : public Type
{
public:

	// A field of a record. Since they aren't created that often
	// at run-time, keep them simple and copy by values.
	class Field
	{
	public:
		// The default constructor creates an invalid field.
		Field() :
			arsz_(0)
		{ }

		// the default copy and assignment are good enough
		
		Field(const string &name, Autoref<Type> t, int arsz = 0) :
			name_(name),
			type_(t),
			arsz_(arsz)
		{ }

	public:
		string name_; // field name
		Autoref <Type> type_; // field type, must really be a simple type
		int arsz_; // hint of array size, 0 means variable (<0 treated the same as 0 for now)
	}; // Field

	RowType(const vector<Field> &fields) :
		Type(false, TT_ROW),
		fields_(fields)
	{ }

	// just make the guts visible read-only to anyone
	const vector<Field> *fields() const
	{
		return &fields_;
	}

	// find a field by name
	// @param fname - field name
	// @return - pointer to the field or NULL
	const Field *find(const string &fname);

	// find a field's index by name
	// @param fname - field name
	// @return - index of the field or -1
	int findIdx(const string &fname);

	// check that the fields are acceptable
	Erref validate();

protected:
	vector<Field> fields_; // what it consists of

private:
	RowType();
};

}; // BICEPS_NS

#endif // __Biceps_RowType_h__
