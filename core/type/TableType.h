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
#include <type/RowHandleType.h>
#include <sched/Gadget.h>

namespace BICEPS_NS {

class Table;
class RootIndexType;
class AggregatorType;

class TableType : public Type
{
	friend class Table;
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
	// structures. The result gets returned by getErrors().
	void initialize();

	// Whether it was already initialized
	bool isInitialized() const
	{
		return initialized_;
	}

	// Get the row type
	const RowType *rowType() const
	{
		return rowType_;
	}

	// Get the row handle type (this one is not constant)
	RowHandleType *rhType() const
	{
		return rhType_;
	}

	// Create an instance table of this type.
	// @param unit - unit where the table belongs
	// @param emode - enqueueing mode for the rowops produced in the table
	// @param name - name of the table,  the input label will be named name.in, the output label name.out,
	//               and the aggregation labels will also be prefixed with the table name and a dot
	// @return - new instance or NULL if not initialized or has an error
	Onceref<Table> makeTable(Unit *unit, Gadget::EnqMode emode, const string &name) const;

	// Find an index type by name.
	// Works only after initialization.
	// @param name - name of the index
	// @return - index, or NULL if not found
	IndexType *findIndex(const string &name) const;

	// Find the first index type of given IndexId
	// Works only after initialization.
	// @param it - type enum of the nested index
	// @return - pointer to the nested index or NULL if none matches
	IndexType *findIndexByIndexId(IndexType::IndexId it) const;

	// Return the first leaf index type.
	// If no indexes defined, returns NULL.
	IndexType *firstLeafIndex() const;

protected:
	typedef vector< Autoref<AggregatorType> > AggVec;

	Autoref<RootIndexType> root_; // the root of index tree
	Autoref<RowType> rowType_; // row for this table
	Erref errors_;
	Autoref<RowHandleType> rhType_; // for building the row handles
	AggVec aggs_; // all the aggregators, collected during initialization
	bool initialized_; // flag: has already been initialized, no more changes allowed

private:
	TableType();
	TableType(const TableType &); // this actually need to be defined later for cloning
	void operator=(const TableType &);
};

}; // BICEPS_NS

#endif // __Biceps_TableType_h__

