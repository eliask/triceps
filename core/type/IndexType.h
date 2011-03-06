//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for creation of indexes in the tables.

#ifndef __Biceps_IndexType_h__
#define __Biceps_IndexType_h__

#include <type/Type.h>
#include <table/GroupHandle.h>
#include <table/Aggregator.h>
#include <common/Errors.h>

namespace BICEPS_NS {

class IndexType;
class TableType;
class AggregatorType;
class RowHandleType;
class GroupHandleType;
class Index;
class Table;
class Aggregator;

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

	// Find the nested index by name.
	// @param name - name of the nested index
	// @return - pointer to the nested index or NULL if unknown name
	IndexType *find(const string &name) const;
	
	// Find the first nested index of given type.
	// @param it - IndexType::IndexId enum of the nested index
	//           (can't use the index type here because it's not defined yet)
	// @return - pointer to the nested index or NULL if none matches
	IndexType *findByIndexId(int it) const;

	// Initialize and validate all indexes in the vector.
	// The errors are returned through parent's getErrors().
	// Includes the checkDups().
	// @param tabtype - table type where this index type belongs (to only one table type!)
	// @param parent - the parent index in the hierarchy
	// @param parentErr - parent's error collection, to append the
	//        indexes' errors
	void initialize(TableType *tabtype, IndexType *parent, Erref parentErr);

	// Check for dups in names.
	// @param err - place to report the name dup errors
	// @return - true on success, false on error
	bool checkDups(Erref parentErr);

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

// Information about connections between index and aggregator types
// is represented as pairs.

class IndexAggTypePair
{
public:
	IndexAggTypePair(IndexType *ind, AggregatorType *agg) :
		index_(ind), agg_(agg)
	{ }

public:
	// index and aggregator types are held elsewhere, this pair simply
	// represents a connection between them, so no need for Autorefs
	IndexType *index_;
	AggregatorType *agg_;
};

typedef vector<IndexAggTypePair> IndexAggTypeVec;

class IndexType : public Type
{
public:
	// subtype of index
	enum IndexId {
		IT_ROOT, // RootIndexType
		IT_PRIMARY, // HashedIndexType
		IT_FIFO, // FifoIndexType
		// add new types here
		IT_LAST
	};

	typedef set<RowHandle *> RhSet;

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

	// Define an aggregator on this index. Each aggregator instance
	// will work on the instance of this index.
	// Potentially there is no reason to limit to only one aggregator
	// but for now it's simpler this way.
	// @param agg - type of the aggregator
	// @return - this
	IndexType *setAggregator(Onceref<AggregatorType> agg);

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
	bool isLeaf() const
	{
		return nested_.empty();
	}

	// Find the nested index by name.
	// @param name - name of the index
	// @return - index type, or NULL if not found
	IndexType *findNested(const string &name) const
	{
		return nested_.find(name);
	}

	// Find the first nested index having the given index type id.
	// @param it - type enum of the nested index
	// @return - index type, or NULL if not found
	IndexType *findNestedByIndexId(IndexId it) const
	{
		return nested_.findByIndexId(it);
	}

	// Return the vector of nested indexes, for iteration
	const IndexTypeVec &getNested() const
	{
		return nested_;
	}

	// Get the first leaf index under this one. If this
	// one is a leaf, returns itself.
	IndexType *getFirstLeaf() const
	{
		if (isLeaf())
			return const_cast<IndexType *>(this);
		else
			return nested_[0].index_->getFirstLeaf();
	}

protected:
	friend class IndexTypeVec;
	friend class TableType;
	friend class Index;
	friend class Table;
	
	// payload section in the GroupHandle, placed at ghOffset_
	struct GhSection {
		size_t size_; // number of records in the section
		Index *subidx_[1]; // sub-indexes of this group - extended as needed
	};

	GhSection *getGhSection(const GroupHandle *rh) const
	{
		return rh->get<GhSection>(ghOffset_);
	}
	Aggregator **getGhAggs(const GroupHandle *rh) const
	{
		return rh->get<Aggregator *>(ghAggOffset_);
	}


	// can be constructed only from subclasses
	IndexType(IndexId it);
	IndexType(const IndexType &orig); 

	// let the index find itself in parent and table type
	// @param tabtype - table type where this index type belongs (to only one table type!)
	// @param parent - the parent index in the hierarchy
	// @param pos - position of this index among siblings
	void setNestPos(TableType *tabtype, IndexType *parent, int pos)
	{
		tabtype_ = tabtype;
		parent_ = parent;
		nestPos_ = pos;
	}

	TableType *getTabtype()
	{
		return tabtype_;
	}

	// Initialize and validate.
	// Guaranteed to be called after setNestPos().
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
	virtual void initialize() = 0;

	// Initialize and validate the nested index types and aggregator(s).
	// Guaranteed to be called after setNestPos() and initialize().
	// Adds their errors to this type's indication getErrors() result.
	void initializeNested();

	bool isInitialized() const
	{
		return initialized_;
	}

	// Add the agggregator typess from this index recursively to the
	// table's vector of them.
	void collectAggregators(IndexAggTypeVec &aggs);
	
	// RowHandle operations.
	// The initialization is done before the handle is inserted into the
	// table, and cleared after is has been removed from the table.
	// So at these times it has no connection to the particular index instance,
	// and these operations belong to th eindex type.
	// {
	
	// Initialize the row handle section for this index and its nested ones:
	// pre-calculate the has values and such for the given row.
	// Normally only the Table class should call it.
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
	virtual void copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const = 0;

	// Find a record in the table, according to this index type.
	// It goes recursively to the root of the table and then back down, finding the
	// concrete path of indexes for this record.
	// @param table - table where to search
	// @param what - handle to search for
	// @return - handle of the record in table or NULL
	RowHandle *findRecord(const Table *table, const RowHandle *what) const;

	// Find the concrete subindex for a subtype.
	// It goes recursively to the root of the table and then back down, finding the
	// concrete path of indexes for this record.
	// @param nestPos - position of the subindex under this one
	// @param table - table where to search
	// @param what - handle to search for
	// @return - concrete index or NULL
	Index *findNestedIndex(int nestPos, const Table *table, const RowHandle *what) const;
	// }
	
public:
	// this should become protected when the call wrappers get added to Index
	
	// GroupHandle operations. Used to control the nested indexes.
	// These operations bring together two parts: this class provides the
	// logic while the group handle provides the set of index instances to
	// apply this logic on.
	// {

	// Copy the handle sections recursively upwards: from here and to the root index.
	// This is normally done to populate the group handles, so named accordingly.
	void copyGroupHandle(GroupHandle *rh, const RowHandle *fromrh) const;

	// Clear the contents of a group handle recursively upwards:
	// from here and to the root index.
	void clearGroupHandle(GroupHandle *rh) const;
	
	// Create a group handle for a new group to contain a new row.
	// The group is returned fully populated with nested indexes.
	// Note that the caller must call incref() afterwards.
	// @param rh - new row for which to create the group, will be used
	//             to copy the cached handle information
	// @param table - table where the index belongs
	// @return - a new group handle, with zero refs
	GroupHandle *makeGroupHandle(const RowHandle *rh, Table *table) const;

	// Destroy the group handle, that must be already empty and unreferenced
	// (this means, removed from the parent index too).
	// This destroys recursively all the indexes contained in the handle
	// and then disposes of the handle itself 
	void destroyGroupHandle(GroupHandle *gh) const;

	// Begin the iteration on the nested indexes:
	// pick the first index in the group and pass the request there.
	// @param gh - the group instance to iterate on, may be NULL
	// @return - the first row in the group according to that index's order,
	//      may be NULL if the group is empty.
	RowHandle *beginIteration(GroupHandle *gh) const;

	// Continue the iteration on the nested indexes:
	// pick the first index in the group and pass the request there.
	// @param gh - the group instance to iterate on, may be NULL
	// @param row - the current (soon to become previous) row in iteration
	// @return - the nest row in the group according to that index's order,
	//      may be NULL if cur was the last row in the group or does not belong
	//      in the group.
	RowHandle *nextIteration(GroupHandle *gh, const RowHandle *cur) const;

	// Find an index instance in the group handle.
	// @param gh - the group instance, may be NULL
	// @param nestPos - position of the nested index
	// @return - index at that position, may be NULL
	Index *groupToIndex(GroupHandle *gh, size_t nestPos) const;

	// Prepare all indexes in group for insertion of the new row handle.
	// Check if it can legally inserted and calculate any records that
	// would be deleted by the replacement policy.
	// If any indexes return false, returns immediately without calling all of them.
	// @param gh - the group instance, may be NULL (in this case returns true)
	// @param rh - new row about to be inserted
	// @param replaced - set to add the handles of replaced rows
	// @return - true if insertion is allowed, false if not
	bool groupReplacementPolicy(GroupHandle *gh, const RowHandle *rh, RhSet &replaced) const;

	// Insert a new row into each index in the group.
	// Increases the size in the group handle.
	// @param gh - the group instance, may NOT be NULL
	// @param rh - new row to insert
	void groupInsert(GroupHandle *gh, RowHandle *rh) const;

	// Remove the row from each index in the group.
	// Before removing calls AO_BEFORE_MOD on all the relevant aggregators
	// (only once on each group).
	// DOES NOT call aggregator AO_AFTER_DELETE.
	// Decreases the size in the group handle.
	// This does NOT collapse the groups that become empty. The record
	// gets actually removed only from the leaf indexes.
	//
	// @param table - table where the group belongs
	// @param gh - the group instance, may NOT be NULL
	// @param rows - set of rows to remove, if two rows happen to be in the
	//     same group then the aggregator AO_BEFORE_MOD needs to be called only once.
	// @param except - set of rows that have already been modified, identifying the
	//     groups for which the aggregator AO_BEFORE_MOD must not be called again.
	void groupRemove(Table *table, GroupHandle *gh, const RhSet &rows, const RhSet &except) const;

	// Call aggregator AO_AFTER_DELETE or AO_AFTER_INSERT (as indicated by aggop)
	// after the rows have been removed or inserted.
	// See the details in Index.h.
	//
	// @param aggop - aggregator operation, AO_AFTER_DELETE or AO_AFTER_INSERT
	// @param table - table where the group belongs
	// @param gh - the group instance, may NOT be NULL
	// @param rows - set of rows that have been removed
	// @param future - set of rows for which the aggregation notifications will
	//        be called separtely in the future, modifies the Rowop::Opcode
	void groupAggregateAfter(Aggregator::AggOp aggop, Table *table, GroupHandle *gh, const RhSet &rows, const RhSet &future) const;

	// Attempt to collapse all the sub-indexes of the group
	// (see the detailed discussion of the semantics in table/Index.h).
	// @param gh - the group instance, may NOT be NULL
	// @param replaced - set of records indentifying the groups that might be collapsible
	// @return - true if the group may be collapsed, i.e. all the sub-indexes agreed 
	//      on collapsing and the group size is 0
	bool groupCollapse(GroupHandle *gh, const RhSet &replaced) const;

	// Get the number of rows in the group.
	// @param gh - the group instance, may be NULL
	size_t groupSize(GroupHandle *gh) const;

	// Clear the data rows in the leaf indexes under this group.
	// @param gh - the group instance, may be NULL
	void groupClearData(GroupHandle *gh) const;

	// Call all the aggregators, telling them that the group is collapsing.
	// @param table - table where the group belongs
	// @param gh - the group instance
	void aggregateCollapse(Table *table, GroupHandle *gh) const;
	// }
protected:

	IndexTypeVec nested_; // nested indices
	TableType *tabtype_; // NOT autoref, to avoid reference loops
	IndexType *parent_; // NOT autoref, to avoid reference loops; NULL for top-level indexes
	Erref errors_;
	Autoref<GroupHandleType> group_; // used to build groups if not leaf
	IndexAggTypeVec groupAggs_; // aggregators of nested indexes, used to build groups
	Autoref<AggregatorType> agg_; // aggregator on this index
	intptr_t ghOffset_; // offset in group handle to the payload section
	intptr_t ghAggOffset_; // offset in group handle to the aggregators subsection
	IndexId indexId_; // identity in case if casting to subtypes is needed (should use typeid instead?)
	int nestPos_; // position, at which this index sits in parent
	bool initialized_; // flag: already initialized, no future changes

private:
	IndexType();
	void operator=(const IndexType &);
};

}; // BICEPS_NS

#endif // __Biceps_IndexType_h__
