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
#include <mem/Row.h>
#include <map>

namespace BICEPS_NS {

class RowType;
	
// Data to be stored in a field of a record.
// The field data are normally passed as a vector. If a row type has N fields,
// then the first N data elements determine the size of the fields and provide
// the initial filling.
// 
// If there are more field data elements, they are treated as overrides:
// fill more data into the existing fields. This allows to assemble the
// field values from multiple sources. The overrides can't go past the
// end of fields, and can not put data into the null fields.
class Fdata 
{
public:
	// set the field to null
	void setNull()
	{
		notNull_ = false;
	}
	// Set the field to point to a buffer
	void setPtr(bool notNull, const void *data, intptr_t len)
	{
		notNull_ = notNull;
		data_ = (const char *)data;
		len_ = len;
	}
	// Set the field by copying it from other row
	// (doesn't add a reference to that row, if needed add manually).
	inline void setFrom(const RowType *rtype, const Row *row, int nf);
	// Set the field as an override
	void setOverride(int nf, intptr_t off, const void *data, intptr_t len)
	{
		nf_ = nf;
		off_ = off;
		data_ = (const char *)data;
		len_ = len;
	}

public:
	Autoref <Row> row_; // in case if data comes from another row, can be used
		// to keep a hold on it, but doesn't have to if the row won't be deleted anyway
	const char *data_; // data to store, may be NULL to just zero-fill
	intptr_t len_; // length of data to store
	intptr_t off_; // for overrides only: offset into the field
	int nf_; // for overrides only: index of field to fill
	bool notNull_; // this field is not null (only for non-overrides)
};
typedef vector<Fdata> FdataVec;


// Type of a record that can be stored in a Window.
// Its subclasses know how to actually work with various concrete
// record formats.
class RowType : public Type
{
public:

	// A field of a record type. Since they aren't created that often
	// at run-time, keep them simple and copy by values.
	class Field
	{
	public:
		// The default constructor creates an invalid field.
		Field();

		// the default copy and assignment are good enough
		
		Field(const string &name, Autoref<const SimpleType> t, int arsz = 0);

	public:
		string name_; // field name
		Autoref <const SimpleType> type_; // field type, must really be a simple type
		int arsz_; // hint of array size, 0 means variable (<0 treated the same as 0 for now)
	}; // Field

	typedef vector<Field> FieldVec;

	// The constructor parses the error definition into the
	// internal format. To get the errors, use getErrors();
	RowType(const FieldVec &fields);

	// Essentially a factory, that creates another row type with the
	// same internal format.
	virtual RowType *newSameFormat(const FieldVec &fields) const = 0;

	// from Type
	virtual Erref getErrors() const;
	virtual bool equals(const Type *t) const;
	virtual bool match(const Type *t) const;

	// just make the guts visible read-only to anyone
	const vector<Field> &fields() const
	{
		return fields_;
	}

	// find a field by name
	// @param fname - field name
	// @return - pointer to the field or NULL
	const Field *find(const string &fname) const;

	// find a field's index by name
	// @param fname - field name
	// @return - index of the field or -1
	int findIdx(const string &fname) const;

	// Get the count of fields
	int fieldCount() const;

	// {
	// Operations on a row of this format.
	// Since they take prow ointers, the row must be held in some
	// other Autoptr to avoid it being destroyed.

	// Check whether a field is NULL
	// @param row - row to operate on
	// @param nf - field number, starting from 0
	virtual bool isFieldNull(const Row *row, int nf) const = 0;

	// Get information to access the field data.
	// @param row - row to operate on
	// @param nf - field number, starting from 0
	// @param ptr - returned pointer to field data
	// @param len - returned field data length
	// @return - true if field is NOT null
	virtual bool getField(const Row *row, int nf, const char *&ptr, intptr_t &len) const = 0;

	// the rows are immutable, so the only way to change a row 
	// is by building a new one
	
	// Split the contents of a row into a data vector. Does not fill in the row_ references.
	// A convenience function working through setFrom().
	// @param row - row to split
	// @param data - vector to return the data into (its old contents will be overwritten
	//    away and vector resized to the number of fields, but no guarantees about
	//    resetting the row_ references)
	void splitInto(const Row *row, FdataVec &data) const;

	// Make a new row from the specified field values. If the vector is too
	// short, it gets extended with nulls.
	// @param data - data to put into the row (not const because of possible nulls extension)
	virtual Onceref<Row> makeRow(FdataVec &data) const = 0;
	
	// Copy a row without any changes. A convenience function, implemented
	// through splitInto and makeRow. It doesn't care about the data types,
	// their meaning and such. It just blindly copies the binary data.
	// @param rtype - type of original row, used to extract the contents
	// @param row - row to copy
	// @return - the newly created row
	Onceref<Row> copyRow(const RowType *rtype, const Row *row) const;

	// A convenience function for building vectors: extends the vector,
	// filling it with nulls. Never shrinks the vector.
	// @param v - vector to fill
	// @param nf - fill to this number of fields
	static void fillFdata(FdataVec &v, int nf);
	// }
	

protected:
	// parse the definition and return the errors, called from the constructor
	Erref parse();

	FieldVec fields_; // what it consists of
	typedef map <string, size_t> IdMap;
	IdMap idmap_; // quick access by name
	Erref errors_; // errors collected during parsing

private:
	RowType();
};

// comes atfter RowType is defined...
inline void Fdata::setFrom(const RowType *rtype, const Row *row, int nf)
{
	notNull_ = rtype->getField(row, nf, data_, len_);
}

}; // BICEPS_NS

#endif // __Biceps_RowType_h__
