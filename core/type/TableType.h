//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for the tables.

#ifndef __Biceps_TableType_h__
#define __Biceps_TableType_h__

#include <type/IndexType.h>
#include <type/RowType.h>

namespace BICEPS_NS {

class TableType;
class TableType;


class TableType : public Type
{
public:
	// @param rt - type of rows in this table
	TableType(Onceref<RowType> rt);
	~TableType();

	// from Type
	virtual Erref getErrors() const; 
	virtual bool equals(const Type *t) const;
	virtual bool match(const Type *t) const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

	// The idea of the configuration methods is that they return back "this",
	// making possible to chain them together with "->".

	// Add a top-level index.
	// @param name - name of the index
	// @param index - the index
	// @return - this
	TableType *addIndex(const string &name, IndexType *index);

	// Check the whole table definition and derive the internal
	// structures. The result gets checked by getErrors().
	void validate();

protected:
	IndexVec topInd_; // top-level indexes
	Autoref<RowType> rowType_; // row for this table
	Erref errors_;

private:
	TableType();
	TableType(const TableType &); // this actually need to be defined later for cloning
	void operator=(const TableType &);
};

}; // BICEPS_NS

#endif // __Biceps_TableType_h__

