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
typedef vector<IndexRef> IndexVec;

class IndexType : public Type
{
public:
	// subtype of index
	enum IndexId {
		IT_PRIMARY, // PrimaryIndexType
		// add new types here
		IT_LAST
	};

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

protected:
	// can be constructed only from subclasses
	IndexType(IndexId it);

protected:
	IndexVec nested_; // nested indices
	TableType *table_; // NOT autoref, to avoid reference loops
	IndexType *parent_; // NOT autoref, to avoid reference loops; NULL for top-level indexes
	IndexId indexId_; // identity in case if casting to subtypes is needed (should use typeid instead?)

private:
	IndexType();
	IndexType(const IndexType &); // this actually need to be defined later for cloning
	void operator=(const IndexType &);
};

}; // BICEPS_NS

#endif // __Biceps_IndexType_h__
