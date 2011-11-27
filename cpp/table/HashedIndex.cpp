//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key.

#include <table/HashedIndex.h>
#include <type/HashedIndexType.h>
#include <type/RowType.h>

namespace TRICEPS_NS {

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
	// fprintf(stderr, "DEBUG HashedIndex::begin(this=%p) found %p (of %d)\n", this, (it == data_.end()?NULL:*it), (int)data_.size());
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
	// fprintf(stderr, "DEBUG HashedIndex::next(this=%p, cur=%p) found %p (of %d)\n", this, cur, (it == data_.end()?NULL:*it), (int)data_.size());
	if (it == data_.end()) {
		// fprintf(stderr, "DEBUG HashedIndex::next(this=%p) return NULL\n", this);
		return NULL;
	} else {
		// fprintf(stderr, "DEBUG HashedIndex::next(this=%p) return %p\n", this, *it);
		return *it;
	}
}

RowHandle *HashedIndex::last() const
{
	if (data_.empty()) {
		return NULL;
	} else {
		Set::iterator it = data_.end();
		--it; // OK because the set has bidirectional iterators
		return *it;
	}
}

const GroupHandle *HashedIndex::nextGroup(const GroupHandle *cur) const
{
	return NULL;
}

const GroupHandle *HashedIndex::beginGroup() const
{
	return NULL;
}

const GroupHandle *HashedIndex::toGroup(const RowHandle *cur) const
{
	return NULL;
}

RowHandle *HashedIndex::find(const RowHandle *what) const
{
	Set::iterator it = data_.find(const_cast<RowHandle *>(what));
	// fprintf(stderr, "DEBUG HashedIndex::find(this=%p, what=%p) found %p (of %d)\n", this, what, (it == data_.end()?NULL:*it), (int)data_.size());
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
	// fprintf(stderr, "DEBUG HashedIndex::insert(this=%p, rh=%p, rs=%p)\n", this, rh, rs);
}

void HashedIndex::remove(RowHandle *rh)
{
	RhSection *rs = less_->getSection(rh);
	// fprintf(stderr, "DEBUG HashedIndex::remove(this=%p, rh=%p, rs=%p)\n", this, rh, rs);
	data_.erase(rs->iter_);
}

void HashedIndex::aggregateBefore(Tray *dest, const RhSet &rows, const RhSet &already, Tray *copyTray)
{ 
	// nothing to do
}

void HashedIndex::aggregateAfter(Tray *dest, Aggregator::AggOp aggop, const RhSet &rows, const RhSet &future, Tray *copyTray)
{ 
	// nothing to do
}

bool HashedIndex::collapse(Tray *dest, const RhSet &replaced, Tray *copyTray)
{
	// fprintf(stderr, "DEBUG HashedIndex::collapse(this=%p, rhset size=%d)\n", this, (int)replaced.size());
	return true;
}


}; // TRICEPS_NS
