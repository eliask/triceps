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
		groups.push_back(*it);
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
		type_->groupClearData(*it);
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
		return type_->beginIteration(*it);
}

RowHandle *PrimaryNestedIndex::next(const RowHandle *cur) const
{
	// fprintf(stderr, "DEBUG PrimaryNestedIndex::next(this=%p, cur=%p)\n", this, cur);
	if (cur == NULL || !cur->isInTable())
		return NULL;

	Set::iterator it = data_.find(static_cast<GroupHandle *>(const_cast<RowHandle *>(cur)));

	if (it != data_.end()) {
		RowHandle *res = type_->nextIteration(*it, cur);
		// fprintf(stderr, "DEBUG PrimaryNestedIndex::next(this=%p) nextIteration local return=%p\n", this, res);
		if (res != NULL)
			return res;
	}

	// otherwise try the next groups until find a non-empty one
	for (++it; it != data_.end(); ++it) {
		RowHandle *res = type_->beginIteration(*it);
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
	Set::iterator it = data_.find(static_cast<GroupHandle *>(const_cast<RowHandle *>(what)));
	if (it == data_.end()) {
		// fprintf(stderr, "DEBUG PrimaryNestedIndex::findNested(this=%p) return NULL\n", this);
		return NULL;
	} else {
		Index *idx = type_->groupToIndex(*it, nestPos);
		// fprintf(stderr, "DEBUG PrimaryNestedIndex::findNested(this=%p) return index %p\n", this, idx);
		return idx;
	}
}

bool PrimaryNestedIndex::replacementPolicy(const RowHandle *rh, RhSet &replaced) const
{
	Set::iterator it = data_.find(static_cast<GroupHandle *>(const_cast<RowHandle *>(rh)));

	if (it == data_.end())
		return true; // will be a new group
	else
		return type_->groupReplacementPolicy(*it, rh, replaced);
}

void PrimaryNestedIndex::insert(RowHandle *rh)
{
	Set::iterator it = data_.find(static_cast<GroupHandle *>(const_cast<RowHandle *>(rh)));

	if (it == data_.end()) { // a new group
		GroupHandle *grp = type_->makeGroupHandle(rh, table_);
		grp->incref();
		pair<Set::iterator, bool> res = data_.insert(grp);
		type_->groupInsert(*res.first, rh);
	} else {
		type_->groupInsert(*it, rh);
	}
}

void PrimaryNestedIndex::remove(RowHandle *rh)
{
	Set::iterator it = data_.find(static_cast<GroupHandle *>(const_cast<RowHandle *>(rh)));
	if (it != data_.end()) {
		type_->groupRemove(*it, rh);
	}
}


}; // BICEPS_NS
