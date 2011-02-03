//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for creation of indexes in the tables.

#ifndef __Biceps_IndexType_h__
#define __Biceps_IndexType_h__

#include <type/Type.h>

namespace BICEPS_NS {

class IndexType;
class TableType;
class Index;

// connection of indexes into a tree
class  IndexRef 
{
public:
	IndexRef(const string &n, IndexType *it) :
		name_(n),
		index_(it)
	{ }


	string name_; // name of the index, for finding it later
	Autoref<IndexType> index_;
};

class IndexVec: public  vector<IndexRef>
{
public:
	IndexVec();
	IndexVec(size_t size);
	// Populate with the copy of the original types
	IndexVec(const IndexVec &orig);

	// Initialize and validate all indexes in the vector.
	// The errors are returned through parent's getErrors().
	// @param table - table type where this index belongs
	// @param parentErr - parent's error collection, to append the
	//        indexes' errors
	void initialize(TableType *table, Erref parentErr);

private:
	void operator=(const IndexVec &);
}

class IndexType : public Type
{
public:
	// subtype of index
	enum IndexId {
		IT_PRIMARY, // PrimaryIndexType
		// add new types here
		IT_LAST
	};

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
	IndexId getSubtype() const
	{ 
		return indexId_; 
	}

	// Make a copy of this type. The copy is always uninitialized, no
	// matter whther it was made from an initialized one or not.
	// The subclasses must define the actual copying.
	virtual IndexType *copy() = 0;

	// Initialize and validate.
	// If already initialized, must return right away.
	// The errors are returned through getErrors().
	// @param tabtype - table type where this index belongs
	virtual void initialize(TableType *tabtype) = 0;

	// Make a new instance of the index.
	// @param tabtype - table type where this index belongs
	// @return - the new instance, or NULL if not initialized or had an error.
	virtual Index *makeIndex(TableType *tabtype) = 0;

protected:
	// can be constructed only from subclasses
	IndexType(IndexId it);
	IndexType(const IndexType &orig); 

protected:
	bool isInitialized() {
		return initialized_;
	}

	IndexVec nested_; // nested indices
	TableType *table_; // NOT autoref, to avoid reference loops
	IndexType *parent_; // NOT autoref, to avoid reference loops; NULL for top-level indexes
	IndexId indexId_; // identity in case if casting to subtypes is needed (should use typeid instead?)
	Erref errors_;
	bool initialized_; // flag: already initialized, no future changes

private:
	IndexType();
	void operator=(const IndexType &);
};

}; // BICEPS_NS

#endif // __Biceps_IndexType_h__
