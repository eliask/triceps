//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Implementation of a simple FIFO storage.

#include <table/FifoIndex.h>
#include <type/RowType.h>

namespace BICEPS_NS {

//////////////////////////// FifoIndex /////////////////////////

FifoIndex::FifoIndex(const TableType *tabtype, Table *table, const FifoIndexType *mytype) :
	Index(tabtype, table),
	type_(mytype),
	first_(NULL),
	last_(NULL),
	size_(0)
{ }

FifoIndex::~FifoIndex()
{
	// the Table will take care of the records
}

void FifoIndex::clearData()
{
	first_ = last_ = NULL;
	size_ = 0;
}

const IndexType *FifoIndex::getType() const
{
	return type_;
}

RowHandle *FifoIndex::begin() const
{
	return first_;
}

RowHandle *FifoIndex::next(const RowHandle *cur) const
{
	if (cur == NULL || !cur->isInTable())
		return NULL;

	RhSection *rs = getSection(cur);
	return rs->next_;
}

RowHandle *FifoIndex::nextGroup(const RowHandle *cur) const
{
	return NULL;
}

RowHandle *FifoIndex::find(const RowHandle *what) const
{
	return NULL; // XXX the only way to find is by full-row comparison, which is not implemented yet 
}

Index *FifoIndex::findNested(const RowHandle *what, int nestPos) const
{
	return NULL;
}

bool FifoIndex::replacementPolicy(const RowHandle *rh, RhSet &replaced)
{
	// XXX ideally should check if there is any other group that is already
	// marked for replacement and present in this index, then don't push out another one.

	size_t limit = type_->getLimit();
	if (limit > 0 && size_ >= limit)
		replaced.insert(first_); 
		
	return true;
}

void FifoIndex::insert(RowHandle *rh)
{
	RhSection *rs = getSection(rh);

	if (first_ == NULL) {
		rs->next_ = 0;
		rs->prev_ = 0;
		first_ = last_ = rh;
	} else {
		rs->next_ = 0;
		rs->prev_ = last_;
		RhSection *lastrs = getSection(last_);
		lastrs->next_ = rh;
		last_ = rh;
	}
	++size_;
}

void FifoIndex::remove(RowHandle *rh)
{
	RhSection *rs = getSection(rh);

	if (first_ == rh) {
		if (last_ == rh) {
			first_ = last_ = NULL; // that was the last row
		} else {
			first_ = rs->next_;
			RhSection *nextrs = getSection(first_);
			nextrs->prev_ = NULL;
		}
	} else if (last_ == rh) {
		last_ = rs->prev_;
		RhSection *prevrs = getSection(last_);
		prevrs->next_ = NULL;
	} else {
		RhSection *nextrs = getSection(rs->next_);
		RhSection *prevrs = getSection(rs->prev_);
		prevrs->next_ = rs->next_;
		nextrs->prev_ = rs->prev_;
	}
	rs->prev_ = rs->next_ = NULL;
	--size_;
}

bool FifoIndex::collapse(const RhSet &replaced)
{
	return true;
}

}; // BICEPS_NS
