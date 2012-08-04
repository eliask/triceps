//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Representation of an ordered set of row types. 

#ifndef __Triceps_RowSetType_h__
#define __Triceps_RowSetType_h__

#include <type/RowType.h>

namespace TRICEPS_NS {

// This is used primarily as the type of FnReturn but may have other
// uses too.
class RowSetType: public Type
{
public:
	typedef map<string, int> NameMap;
	typedef vector<string> NameVec; 
	typedef vector<Autoref<RowType> > RowTypeVec; 

	// It's created empty and then the row types are added one by one.
	// After the last one you may call fixate() to prevent more types
	// added accidentally in the future.
	// Check getErrors() after you've added the last one.
	// The typical use is:
	// 
	// Autoref<RowSetType> rst = RowSetType()
	//     ->addRow("name1", rt1)
	//     ->addRow("name2", rt2)
	//     ->fixate();
	RowSetType();

	// A convenience wrapper for the constructor
	static RowSetType *make()
	{
		return new RowSetType;
	}

	// Add a row type to the end of the list.
	// If there are any errors (duplicate names etc), they will be returned 
	// later in getErrors().
	//
	// May throw an exception if the type is already fixed.
	//
	// @param rname - name of this element
	// @param rtype - row type for this element
	// @return - the same RowSetType object, for chained calls
	RowSetType *addRow(const string &rname, Autoref<RowType>rtype);
	
	// After this call any attempts to add a row will cause an abort.
	// Pretty much, a diagnostic tool.
	RowSetType *fixate()
	{
		fixed_ = true;
		return this;
	}

	// A way to find out if this type is still changeable.
	bool isFixed() const
	{
		return fixed_;
	}

	// get the contents info
	const NameVec &getRowNames() const
	{
		return names_;
	}
	const RowTypeVec &getRowTypes() const
	{
		return types_;
	}

	// Translate the row name to its index in the internal array. This index
	// can later be used to get the row type quickly.
	// @param name - the name of the row, as was specified in addRow()
	// @return - the index, or -1 if not found
	int findName(const string &name) const;

	// Get a row type by name.
	// @param name - the name of the row type, as was specified in addRow()
	// @return - the row type, or NULL if not found
	RowType *getRowType(const string &name) const;
	
	// Get a row type by its index in the internal array.
	// @param idx - the index, as might be returned by findName()
	// @return - the row type, or NULL if not found
	RowType *getRowType(int idx) const;

	// from Type
	virtual Erref getErrors() const;
	virtual bool equals(const Type *t) const;
	// The matching returns have the same number of labels, of matching row types,
	// and the names are not important.
	virtual bool match(const Type *t) const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

protected:
	NameMap nameMap_; // mapping of names to indexes
	NameVec names_; // names in sequence
	RowTypeVec types_; // row types in sequence
	Erref errors_; // errors collected during build
	bool fixed_; // flag: fields can not be added any more

	// XXX a copy constructor should be fine if errors_ is NULL
};

}; // TRICEPS_NS

#endif // __Triceps_RowSetType_h__

