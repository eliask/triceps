//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key with further nesting.

#include <table/HashedNestedIndex.h>
#include <type/HashedIndexType.h>
#include <type/RowType.h>

namespace BICEPS_NS {

//////////////////////////// HashedNestedIndex /////////////////////////

HashedNestedIndex::HashedNestedIndex(const TableType *tabtype, Table *table, const HashedIndexType *mytype, Less *lessop) :
	Index(tabtype, table),
	data_(*lessop),
	type_(mytype),
	less_(lessop)
{ }

HashedNestedIndex::~HashedNestedIndex()
{
	vector<GroupHandle *> groups;
	groups.reserve(data_.size());
	for (Set::iterator it = data_.begin(); it != data_.end(); ++it) {
		groups.push_back(static_cast<GroupHandle *>(*it));
	}
	data_.clear();
	size_t n = groups.size();
	for (size_t i = 0; i < n; i++) {
		GroupHandle *gh = groups[i];
		if (gh->decref() <= 0)
			type_->destroyGroupHandle(gh);
	}
}

void HashedNestedIndex::clearData()
{
	// pass recursively into the groups
	for (Set::iterator it = data_.begin(); it != data_.end(); ++it) {
		type_->groupClearData(static_cast<GroupHandle *>(*it));
	}
}

const IndexType *HashedNestedIndex::getType() const
{
	return type_;
}

RowHandle *HashedNestedIndex::begin() const
{
	Set::iterator it = data_.begin();
	if (it == data_.end())
		return NULL;
	else
		return type_->beginIteration(static_cast<GroupHandle *>(*it));
}

RowHandle *HashedNestedIndex::next(const RowHandle *cur) const
{
	// fprintf(stderr, "DEBUG HashedNestedIndex::next(this=%p, cur=%p)\n", this, cur);
	if (cur == NULL || !cur->isInTable())
		return NULL;

	Set::iterator it = data_.find(const_cast<RowHandle *>(cur));

	if (it != data_.end()) {
		RowHandle *res = type_->nextIteration(static_cast<GroupHandle *>(*it), cur);
		// fprintf(stderr, "DEBUG HashedNestedIndex::next(this=%p) nextIteration local return=%p\n", this, res);
		if (res != NULL)
			return res;
	}

	// otherwise try the next groups until find a non-empty one
	for (++it; it != data_.end(); ++it) {
		RowHandle *res = type_->beginIteration(static_cast<GroupHandle *>(*it));
		// fprintf(stderr, "DEBUG HashedNestedIndex::next(this=%p) beginIteration return=%p\n", this, res);
		if (res != NULL)
			return res;
	}
	// fprintf(stderr, "DEBUG HashedNestedIndex::next(this=%p) return NULL\n", this);

	return NULL;
}

RowHandle *HashedNestedIndex::nextGroup(const RowHandle *cur) const
{
	// XXX doesn't make sense at the moment, need to redesign
	return NULL;
}

RowHandle *HashedNestedIndex::find(const RowHandle *what) const
{
	return NULL; // no records directly here
}

Index *HashedNestedIndex::findNested(const RowHandle *what, int nestPos) const
{
	// fprintf(stderr, "DEBUG HashedNestedIndex::findNested(this=%p, what=%p, nestPos=%d)\n", this, what, nestPos);
	if (what == NULL) {
		if (data_.empty())
			return NULL;
		Set::iterator it = data_.begin();
		Index *idx = type_->groupToIndex(static_cast<GroupHandle *>(*it), nestPos);
		// fprintf(stderr, "DEBUG HashedNestedIndex::findNested(this=%p) return index %p\n", this, idx);
		return idx;
	} else {
		Set::iterator it = data_.find(const_cast<RowHandle *>(what));
		if (it == data_.end()) {
			// fprintf(stderr, "DEBUG HashedNestedIndex::findNested(this=%p) return NULL\n", this);
			return NULL;
		} else {
			Index *idx = type_->groupToIndex(static_cast<GroupHandle *>(*it), nestPos);
			// fprintf(stderr, "DEBUG HashedNestedIndex::findNested(this=%p) return index %p\n", this, idx);
			return idx;
		}
	}
}

bool HashedNestedIndex::replacementPolicy(const RowHandle *rh, RhSet &replaced)
{
	Set::iterator it = data_.find(const_cast<RowHandle *>(rh));
	// the result of find() can be stored now in rh, to avoid look-up on insert
	type_->getSection(rh)->iter_ = it;
	GroupHandle *gh;
	// fprintf(stderr, "DEBUG HashedNestedIndex::replacementPolicy(this=%p, rh=%p) put iterValid=%d\n", this, rh, it != data_.end());

	if (it == data_.end()) {
		gh = type_->makeGroupHandle(rh, table_);
		gh->incref();
		pair<Set::iterator, bool> res = data_.insert(gh);
		type_->getSection(rh)->iter_ = res.first;
		type_->getSection(gh)->iter_ = res.first;
	} else {
		gh = static_cast<GroupHandle *>(*it);
	}
	return type_->groupReplacementPolicy(gh, rh, replaced);
}

void HashedNestedIndex::insert(RowHandle *rh)
{
	Set::iterator it = type_->getIter(rh); // has been initialized in replacementPolicy()
	// fprintf(stderr, "DEBUG HashedNestedIndex::insert(this=%p, rh=%p) put iterValid=%d\n", this, rh, it != data_.end());

	type_->groupInsert(static_cast<GroupHandle *>(*it), rh);
}

void HashedNestedIndex::remove(RowHandle *rh)
{
	Set::iterator it = type_->getIter(rh); // row is known to be in the table
	type_->groupRemove(static_cast<GroupHandle *>(*it), rh);
}

void HashedNestedIndex::splitRhSet(const RhSet &rows, SplitMap &dest)
{
	for(RhSet::iterator rsi = rows.begin(); rsi != rows.end(); ++rsi) {
		RowHandle *rh = *rsi;
		Set::iterator si = type_->getIter(rh); // row is known to still be in the set
		dest[static_cast<GroupHandle *>(*si)].insert(rh);
	}
}

void HashedNestedIndex::aggregateBefore(Tray *dest, const RhSet &rows, const RhSet &already, Tray *copyTray)
{
	SplitMap splitRows, splitAlready;
	splitRhSet(rows, splitRows);
	if (!already.empty())
		splitRhSet(already, splitAlready);

	for(SplitMap::iterator smi = splitRows.begin(); smi != splitRows.end(); ++smi) {
		GroupHandle *gh = smi->first;
		if (already.empty()) { // a little optimization
			type_->groupAggregateBefore(dest, table_, gh, smi->second, already, copyTray);
		} else {
			// this automatically creates a new entry in splitAlready if it was missing
			type_->groupAggregateBefore(dest, table_, gh, smi->second, splitAlready[gh], copyTray);
		}
	}
}

void HashedNestedIndex::aggregateAfter(Tray *dest, Aggregator::AggOp aggop, const RhSet &rows, const RhSet &future, Tray *copyTray)
{
	SplitMap splitRows, splitFuture;
	splitRhSet(rows, splitRows);
	if (!future.empty())
		splitRhSet(future, splitFuture);

	for(SplitMap::iterator smi = splitRows.begin(); smi != splitRows.end(); ++smi) {
		GroupHandle *gh = smi->first;
		if (future.empty()) { // a little optimization
			type_->groupAggregateAfter(dest, aggop, table_, gh, smi->second, future, copyTray);
		} else {
			// this automatically creates a new entry in splitFuture if it was missing
			type_->groupAggregateAfter(dest, aggop, table_, gh, smi->second, splitFuture[gh], copyTray);
		}
	}
}

bool HashedNestedIndex::collapse(Tray *dest, const RhSet &replaced, Tray *copyTray)
{
	// fprintf(stderr, "DEBUG HashedNestedIndex::collapse(this=%p, rhset size=%d)\n", this, (int)replaced.size());
	
	// split the set into subsets by iterator
	SplitMap split;
	splitRhSet(replaced, split);

	bool res = true;

	// handle each subset's group
	for(SplitMap::iterator smi = split.begin(); smi != split.end(); ++smi) {
		GroupHandle *gh = smi->first;
		// fprintf(stderr, "DEBUG HashedNestedIndex::collapse(this=%p) gh=%p\n", this, gh);
		if (type_->groupCollapse(dest, gh, smi->second, copyTray)) {
			// fprintf(stderr, "DEBUG HashedNestedIndex::collapse(this=%p) gh=%p destroying\n", this, gh);
			// call the aggregators to process collapse
			if (!type_->groupAggs_.empty()) {
				type_->aggregateCollapse(dest, table_, gh, copyTray);
			}
			// destroy the group
			data_.erase(type_->getIter(gh)); // after this the iterator in gh is not valid any more
			if (gh->decref() <= 0)
				type_->destroyGroupHandle(gh);
		} else {
			// fprintf(stderr, "DEBUG HashedNestedIndex::collapse(this=%p) gh=%p not collapsing\n", this, gh);
			// a group objects to being collapsed
			res = false;
		}
	}

	return res;
}


}; // BICEPS_NS
