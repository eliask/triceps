//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The common interface for indexes.

#ifndef __Biceps_Index_h__
#define __Biceps_Index_h__

#include <mem/Mtarget.h>
#include <common/Common.h>
#include <type/IndexType.h>

namespace BICEPS_NS {

class TableType;
class IndexType;
class Table;
class Index;

// mirrors IndexTypeRef
// connection of indexes into a tree
class  IndexRef 
{
public:
	IndexRef(const string &n, Index *i);
	IndexRef();

	string name_; // name of the index, for finding it later
	Autoref<Index> index_;
};

// mirrors IndexTypeVec
class IndexVec: public  vector<IndexRef>
{
public:
	IndexVec();
	IndexVec(size_t size);
	// Populate with the copy of the original types
	// IndexVec(const IndexVec &orig);

	// Find the nested index by name.
	// @param name - name of the nested index
	// @return - pointer to the nested index or NULL if unknown name
	Index *find(const string &name) const;
	
	// Find the first nested index of given type.
	// @param it - type enum of the nested index
	// @return - pointer to the nested index or NULL if none matches
	Index *findByType(IndexType::IndexId it) const;

private:
	void operator=(const IndexVec &);
};

// Indexes should be accessed only in one thread, so maybe Straget 
// would be a better choice.
class Index : public Mtarget
{
	friend class IndexType;
public:
	virtual ~Index();

	// Clear the contents of the index. The actual RowHandles are guaranteed
	// to be still held by the table, so the cleaning can be fast.
	virtual void clearData() = 0;

	// Get the type of this index: le the subclass sort it out
	virtual const IndexType *getType() const = 0;

	// Find the nested index by name.
	// @param name - name of the index
	// @return - index, or NULL if not found
	Index *findIndex(const string &name) const
	{
		return nested_.find(name);
	}

	// Find the first nested index of given type.
	// @param it - type enum of the nested index
	// @return - pointer to the nested index or NULL if none matches
	Index *findIndexByType(IndexType::IndexId it) const
	{
		return nested_.findByType(it);
	}

	// Return the indev vector.
	const IndexVec &getIndexVec() const
	{
		return nested_;
	}

	// Get the type id of this index
	IndexType::IndexId getIndexId() const
	{
		return getType()->getIndexId();
	}

protected:
	// always created through subclasses
	Index(const TableType *tabtype, Table *table);
	
protected:
	IndexVec nested_; // nested indices
	// no reference to the type because they're better in subclasses
	Autoref<const TableType> tabType_; // type of the table where it belongs
	Table *table_; // not Autoref, to avoid circularf references

private:
	Index();
	Index(const Index &);
	void operator=(const Index &);
};

}; // BICEPS_NS

#endif // __Biceps_Index_h__
