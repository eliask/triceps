//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for creation of indexes in the tables.

#ifndef __Biceps_IndexType_h__
#define __Biceps_IndexType_h__

#include <type/Type.h>
#include <table/RowHandle.h>
#include <common/Errors.h>

namespace BICEPS_NS {

class IndexType;
class TableType;
class RowHandleType;
class GroupHandleType;
class Index;
class Table;
class IndexVec;

// connection of indexes into a tree
class  IndexTypeRef 
{
public:
	IndexTypeRef(const string &n, IndexType *it);
	IndexTypeRef();
	// IndexTypeRef(const IndexTypeRef &orig); // the default one should be fine

	string name_; // name of the index, for finding it later
	Autoref<IndexType> index_;
};

class IndexTypeVec: public  vector<IndexTypeRef>
{
public:
	IndexTypeVec();
	IndexTypeVec(size_t size);
	// Populate with the copy of the original types
	IndexTypeVec(const IndexTypeVec &orig);

	// Initialize and validate all indexes in the vector.
	// The errors are returned through parent's getErrors().
	// Includes the checkDups().
	// @param table - table type where this index belongs
	// @param parentErr - parent's error collection, to append the
	//        indexes' errors
	void initialize(TableType *table, Erref parentErr);

	// Check for dups in names.
	// @param err - place to report the name dup errors
	// @return - true on success, false on error
	bool checkDups(Erref parentErr);

	// create the indexes for the types stored here
	// @param tabtype - table type where this index belongs
	// @param table - the actuall table instance where this index belongs
	// @param idx - the index vector to keep the created indexes
	void makeIndexes(const TableType *tabtype, Table *table, IndexVec *ivec) const;

	// Append the human-readable list of type definitions to a string
	// @param res - the resulting string to append to
	// @param indent - initial indentation characters, 
	//        passing NOINDENT prints everything in a single line
	// @param subindent - indentation characters to add on each level
	void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

	// Initialize the row handle section for the nested indexes, recursively:
	// pre-calculate the has values and such for the given row.
	void initRowHandle(RowHandle *rh) const;

	// Clear any references to these index types' dynamically allocated data
	// from this handle.
	void clearRowHandle(RowHandle *rh) const;

private:
	void operator=(const IndexTypeVec &);
};

class IndexType : public Type
{
public:
	// subtype of index
	enum IndexId {
		IT_ROOT, // RootIndexType
		IT_PRIMARY, // PrimaryIndexType
		IT_FIFO, // FifoIndexType
		// add new types here
		IT_LAST
	};

	~IndexType();

	// from Type
	virtual Erref getErrors() const; 
	virtual bool equals(const Type *t) const;
	virtual bool match(const Type *t) const;

	// The idea of the configuration methods is that they return back "this",
	// making possible to chain them together with "->".

	// Add a nested index under this one.
	// @param name - name of the nested index
	// @param index - the nested index
	// @return - this
	IndexType *addNested(const string &name, IndexType *index);

	// For access of subclasses to the subtype id.
	IndexId getIndexId() const
	{ 
		return indexId_; 
	}

	// Make a copy of this type. The copy is always uninitialized, no
	// matter whther it was made from an initialized one or not.
	// The subclasses must define the actual copying.
	virtual IndexType *copy() const = 0;

	// Make a new instance of the index.
	// @param tabtype - table type where this index belongs
	// @param table - the actuall table instance where this index belongs
	// @return - the new instance, or NULL if not initialized or had an error.
	virtual Index *makeIndex(const TableType *tabtype, Table *table) const = 0;

	// @return - true if there are no nested indexes
	bool isLeaf()
	{
		return nested_.empty();
	}

protected:
	friend class IndexTypeVec;
	friend class TableType;
	friend class Table;

	// can be constructed only from subclasses
	IndexType(IndexId it);
	IndexType(const IndexType &orig); 

	// wrapper to access friend-only data
	// @return - ind->nested_
	static IndexVec *getIndexVec(Index *ind);

	// let the index find itself in parent
	void setNestPos(IndexType *parent, int pos)
	{
		parent_ = parent;
		nestPos_ = pos;
	}

	// Initialize and validate.
	// If already initialized, must return right away.
	//
	// DOES NOT INITIALIZE THE NESTED INDEX TYPES.
	// This is very important to have the RowHandle filled out in the correct
	// order, depth-last. The subindexes are initialized with initializeNested().
	// Also if this function created an empty Errors object, it should not
	// try to optimize by deleting it afterwards because it will be used
	// again by initializeNested().
	//
	// The errors are returned through getErrors().
	// @param tabtype - table type where this index belongs
	virtual void initialize(TableType *tabtype) = 0;

	// Initialize and validate the nested index types.
	// Adds their errors to this type's indication getErrors() result.
	// @param tabtype - table type where this index belongs
	void initializeNested(TableType *tabtype);

	bool isInitialized() const
	{
		return initialized_;
	}
	
	// a wrapper
	void makeNestedIndexes(const TableType *tabtype, Table *table, IndexVec *ivec) const
	{
		return nested_.makeIndexes(tabtype, table, ivec);
	}

	// RowHandle operations.
	// The initialization is done before the handle is inserted into the
	// table, and cleared after is has been removed from the table.
	// So at these times it has no connection to the particular index instance,
	// and these operations belong to th eindex type.
	// {
	
	// Initialize the row handle section for this index and its nested ones:
	// pre-calculate the has values and such for the given row.
	// Normally only the Table class should call it (maybe through IndexVec).
	virtual void initRowHandleSection(RowHandle *rh) const = 0;

	// Initialize the row handle recursively with nested indexes.
	void initRowHandle(RowHandle *rh) const
	{
		initRowHandleSection(rh);
		nested_.initRowHandle(rh);
	}

	// Clear any references to this index type's dynamically allocated data
	// from this handle.
	virtual void clearRowHandleSection(RowHandle *rh) const = 0;
	// Clear recursively, with nested indexes.
	void clearRowHandle(RowHandle *rh) const
	{
		clearRowHandleSection(rh);
		nested_.clearRowHandle(rh);
	}

	// Copy the precalculated row handle values from one row's handle
	// to another handle for the same row.
	// (This is used to initialize the group handles, which would normally be the destinations).
	// @param rh - row handle to initialize
	// @param fromrh - the original handle
	virtual void copyRowHandleSection(RowHandle *rh, RowHandle *fromrh) const = 0;

	// }
protected:

	IndexTypeVec nested_; // nested indices
	TableType *table_; // XXX unused yet // NOT autoref, to avoid reference loops
	IndexType *parent_; // NOT autoref, to avoid reference loops; NULL for top-level indexes
	Erref errors_;
	Autoref<GroupHandleType> group_; // used to build groups if not leaf
	intptr_t ghOffSubidx_; // offset in group handle to the array of pointers to nested indexes
	IndexId indexId_; // identity in case if casting to subtypes is needed (should use typeid instead?)
	int nestPos_; // position, at which this index sits in parent
	bool initialized_; // flag: already initialized, no future changes

private:
	IndexType();
	void operator=(const IndexType &);
};

}; // BICEPS_NS

#endif // __Biceps_IndexType_h__
