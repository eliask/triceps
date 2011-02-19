//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key with further nesting.

#include <table/PrimaryNestedIndex.h>
#include <type/PrimaryIndexType.h>
#include <type/RowType.h>

namespace BICEPS_NS {

//////////////////////////// PrimaryNestedIndex /////////////////////////

PrimaryNestedIndex::PrimaryNestedIndex(const TableType *tabtype, Table *table, const PrimaryIndexType *mytype, Less *lessop) :
	Index(tabtype, table),
	data_(*lessop),
	type_(mytype),
	less_(lessop)
{ }

PrimaryNestedIndex::~PrimaryNestedIndex()
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

void PrimaryNestedIndex::clearData()
{
	// pass recursively into the groups
	for (Set::iterator it = data_.begin(); it != data_.end(); ++it) {
		type_->groupClearData(static_cast<GroupHandle *>(*it));
	}
}

const IndexType *PrimaryNestedIndex::getType() const
{
	return type_;
}

RowHandle *PrimaryNestedIndex::begin() const
{
	Set::iterator it = data_.begin();
	if (it == data_.end())
		return NULL;
	else
		return type_->beginIteration(static_cast<GroupHandle *>(*it));
}

RowHandle *PrimaryNestedIndex::next(const RowHandle *cur) const
{
	// fprintf(stderr, "DEBUG PrimaryNestedIndex::next(this=%p, cur=%p)\n", this, cur);
	if (cur == NULL || !cur->isInTable())
		return NULL;

	Set::iterator it = data_.find(const_cast<RowHandle *>(cur));

	if (it != data_.end()) {
		RowHandle *res = type_->nextIteration(static_cast<GroupHandle *>(*it), cur);
		// fprintf(stderr, "DEBUG PrimaryNestedIndex::next(this=%p) nextIteration local return=%p\n", this, res);
		if (res != NULL)
			return res;
	}

	// otherwise try the next groups until find a non-empty one
	for (++it; it != data_.end(); ++it) {
		RowHandle *res = type_->beginIteration(static_cast<GroupHandle *>(*it));
		// fprintf(stderr, "DEBUG PrimaryNestedIndex::next(this=%p) beginIteration return=%p\n", this, res);
		if (res != NULL)
			return res;
	}
	// fprintf(stderr, "DEBUG PrimaryNestedIndex::next(this=%p) return NULL\n", this);

	return NULL;
}

RowHandle *PrimaryNestedIndex::nextGroup(const RowHandle *cur) const
{
	// XXX doesn't make sense at the moment, need to redesign
	return NULL;
}

RowHandle *PrimaryNestedIndex::find(const RowHandle *what) const
{
	return NULL; // no records directly here
}

Index *PrimaryNestedIndex::findNested(const RowHandle *what, int nestPos) const
{
	// fprintf(stderr, "DEBUG PrimaryNestedIndex::findNested(this=%p, what=%p, nestPos=%d)\n", this, what, nestPos);
	Set::iterator it = data_.find(const_cast<RowHandle *>(what));
	if (it == data_.end()) {
		// fprintf(stderr, "DEBUG PrimaryNestedIndex::findNested(this=%p) return NULL\n", this);
		return NULL;
	} else {
		Index *idx = type_->groupToIndex(static_cast<GroupHandle *>(*it), nestPos);
		// fprintf(stderr, "DEBUG PrimaryNestedIndex::findNested(this=%p) return index %p\n", this, idx);
		return idx;
	}
}

bool PrimaryNestedIndex::replacementPolicy(const RowHandle *rh, RhSet &replaced) const
{
	Set::iterator it = data_.find(const_cast<RowHandle *>(rh));
	// XXX the result of find() can be stored in rh, to avoid look-up on insert

	if (it == data_.end())
		return true; // will be a new group
	else
		return type_->groupReplacementPolicy(static_cast<GroupHandle *>(*it), rh, replaced);
}

void PrimaryNestedIndex::insert(RowHandle *rh)
{
	Set::iterator it = data_.find(const_cast<RowHandle *>(rh));

	if (it == data_.end()) { // a new group
		GroupHandle *grp = type_->makeGroupHandle(rh, table_);
		grp->incref();
		pair<Set::iterator, bool> res = data_.insert(grp);
		type_->groupInsert(static_cast<GroupHandle *>(*res.first), rh);
	} else {
		type_->groupInsert(static_cast<GroupHandle *>(*it), rh);
	}
}

void PrimaryNestedIndex::remove(RowHandle *rh)
{
	// XXX don't find(), use the direct iterator
	Set::iterator it = data_.find(const_cast<RowHandle *>(rh));
	if (it != data_.end()) {
		type_->groupRemove(static_cast<GroupHandle *>(*it), rh);
	}
}

bool PrimaryNestedIndex::collapse(const RhSet &replaced)
{
	// split the set into subsets by iterator
	typedef map<GroupHandle *, RhSet> SplitMap;
	SplitMap split;

	for(RhSet::iterator rsi = replaced.begin(); rsi != replaced.end(); ++rsi) {
		RowHandle *rh = *rsi;
		Set::iterator si = type_->getIter(rh); // row is known to still be in the set
		split[static_cast<GroupHandle *>(*si)].insert(rh);
	}

	bool res = true;

	// handle each subset's group
	for(SplitMap::iterator smi = split.begin(); smi != split.end(); ++smi) {
		GroupHandle *gh = smi->first;
		if (type_->groupCollapse(gh, smi->second)) {
			// destroy the group
			data_.erase(type_->getIter(gh)); // after this the iterator in gh is not valid any more
			if (gh->decref() <= 0)
				type_->destroyGroupHandle(gh);
		} else {
			// a group objects to being collapsed
			res = false;
		}
	}

	return res;
}


}; // BICEPS_NS
