//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key.

#include <table/HashedIndex.h>
#include <type/HashedIndexType.h>
#include <type/RowType.h>

namespace BICEPS_NS {

//////////////////////////// HashedIndex /////////////////////////

HashedIndex::HashedIndex(const TableType *tabtype, Table *table, const HashedIndexType *mytype, Less *lessop) :
	Index(tabtype, table),
	data_(*lessop),
	type_(mytype),
	less_(lessop)
{ }

HashedIndex::~HashedIndex()
{
	assert(data_.empty());
}

void HashedIndex::clearData()
{
	data_.clear();
}

const IndexType *HashedIndex::getType() const
{
	return type_;
}

RowHandle *HashedIndex::begin() const
{
	Set::iterator it = data_.begin();
	if (it == data_.end())
		return NULL;
	else
		return *it;
}

RowHandle *HashedIndex::next(const RowHandle *cur) const
{
	// fprintf(stderr, "DEBUG HashedIndex::next(this=%p, cur=%p)\n", this, cur);
	if (cur == NULL || !cur->isInTable())
		return NULL;

	RhSection *rs = less_->getSection(cur);
	Set::iterator it = rs->iter_;
	++it;
	if (it == data_.end()) {
		// fprintf(stderr, "DEBUG HashedIndex::next(this=%p) return NULL\n", this);
		return NULL;
	} else {
		// fprintf(stderr, "DEBUG HashedIndex::next(this=%p) return %p\n", this, *it);
		return *it;
	}
}

RowHandle *HashedIndex::nextGroup(const RowHandle *cur) const
{
	return NULL;
}

RowHandle *HashedIndex::find(const RowHandle *what) const
{
	Set::iterator it = data_.find(const_cast<RowHandle *>(what));
	if (it == data_.end())
		return NULL;
	else
		return (*it);
}

Index *HashedIndex::findNested(const RowHandle *what, int nestPos) const
{
	return NULL;
}

bool HashedIndex::replacementPolicy(const RowHandle *rh, RhSet &replaced)
{
	Set::iterator old = data_.find(const_cast<RowHandle *>(rh));
	// XXX for now just silently replace the old value with the same key
	if (old != data_.end())
		replaced.insert(*old);
	return true;
}

void HashedIndex::insert(RowHandle *rh)
{
	pair<Set::iterator, bool> res = data_.insert(const_cast<RowHandle *>(rh));
	assert(res.second); // must always succeed
	RhSection *rs = less_->getSection(rh);
	rs->iter_ = res.first;
	// fprintf(stderr, "DEBUG HashedIndex::insert(this=%p, rh=%p)\n", this, rh);
}

void HashedIndex::remove(RowHandle *rh)
{
	RhSection *rs = less_->getSection(rh);
	data_.erase(rs->iter_);
}

void HashedIndex::aggregateBefore(const RhSet &rows, const RhSet &already, Tray *copyTray)
{ 
	// nothing to do
}

void HashedIndex::aggregateAfter(Aggregator::AggOp aggop, const RhSet &rows, const RhSet &future, Tray *copyTray)
{ 
	// nothing to do
}

bool HashedIndex::collapse(const RhSet &replaced, Tray *copyTray)
{
	// fprintf(stderr, "DEBUG HashedIndex::collapse(this=%p, rhset size=%d)\n", this, (int)replaced.size());
	return true;
}


}; // BICEPS_NS
