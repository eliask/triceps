//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple primary key.

#include <table/PrimaryIndex.h>
#include <type/PrimaryIndexType.h>
#include <type/RowType.h>

namespace BICEPS_NS {

//////////////////////////// PrimaryIndex /////////////////////////

PrimaryIndex::PrimaryIndex(const TableType *tabtype, Table *table, const PrimaryIndexType *mytype, Less *lessop) :
	Index(tabtype, table),
	data_(*lessop),
	type_(mytype),
	less_(lessop)
{ }

PrimaryIndex::~PrimaryIndex()
{
	assert(data_.empty());
}

void PrimaryIndex::clearData()
{
	data_.clear();
}

const IndexType *PrimaryIndex::getType() const
{
	return type_;
}

RowHandle *PrimaryIndex::begin() const
{
	Set::iterator it = data_.begin();
	if (it == data_.end())
		return NULL;
	else
		return *it;
}

RowHandle *PrimaryIndex::next(RowHandle *cur) const
{
	if (cur == NULL || !cur->isInTable())
		return NULL;

	RhSection *rs = less_->getSection(cur);
	Set::iterator it = rs->iter_;
	++it;
	if (it == data_.end())
		return NULL;
	else
		return *it;
}

RowHandle *PrimaryIndex::nextGroup(RowHandle *cur) const
{
	return NULL;
}

RowHandle *PrimaryIndex::find(RowHandle *what) const
{
	Set::iterator it = data_.find(what);
	if (it == data_.end())
		return NULL;
	else
		return (*it);
}

bool PrimaryIndex::replacementPolicy(RowHandle *rh, RhSet &replaced) const
{
	Set::iterator old = data_.find(rh);
	// XXX for now just silently replace the old value with the same key
	if (old != data_.end())
		replaced.insert(*old);
	return true;
}

void PrimaryIndex::insert(RowHandle *rh)
{
	pair<Set::iterator, bool> res = data_.insert(rh);
	assert(res.second); // must always succeed
	RhSection *rs = less_->getSection(rh);
	rs->iter_ = res.first;
}

void PrimaryIndex::remove(RowHandle *rh)
{
	RhSection *rs = less_->getSection(rh);
	data_.erase(rs->iter_);
}


}; // BICEPS_NS
