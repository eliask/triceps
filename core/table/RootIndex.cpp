//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The pseudo-index for the root of the index tree.

#include <table/RootIndex.h>
#include <type/RowType.h>

namespace BICEPS_NS {

//////////////////////////// RootIndex /////////////////////////

RootIndex::RootIndex(const TableType *tabtype, Table *table, const RootIndexType *mytype) :
	Index(tabtype, table),
	type_(mytype),
	rootg_(NULL)
{ }

RootIndex::~RootIndex()
{
	// the Table will take care of the records but for now need to free the group
	if (rootg_) {
		if (rootg_->decref() <= 0)
			type_->destroyGroupHandle(rootg_);
	}
}

void RootIndex::clearData()
{ 
	type_->groupClearData(rootg_);
}

const IndexType *RootIndex::getType() const
{
	return type_;
}

RowHandle *RootIndex::begin() const
{
	return type_->beginIteration(rootg_);
}

RowHandle *RootIndex::next(const RowHandle *cur) const
{
	return type_->nextIteration(rootg_, cur);
}

RowHandle *RootIndex::nextGroup(const RowHandle *cur) const
{
	// XXX doesn't make sense at the moment, need to redesign
	return NULL;
}

RowHandle *RootIndex::find(const RowHandle *what) const
{
	return NULL; // no records directly here
}

Index *RootIndex::findNested(const RowHandle *what, int nestPos) const
{
	Index *idx = type_->groupToIndex(rootg_, nestPos);
	// fprintf(stderr, "DEBUG RootIndex::findNested(this=%p) return index %p\n", this, idx);
	return idx;
}

bool RootIndex::replacementPolicy(const RowHandle *rh, RhSet &replaced)
{
	// fprintf(stderr, "DEBUG RootIndex::replacementPolicy(this=%p, rh=%p)\n", this, rh);
	if (rootg_ == NULL) {
		// create a new group
		rootg_ = type_->makeGroupHandle(rh, table_);
		rootg_->incref();
	}
	return type_->groupReplacementPolicy(rootg_, rh, replaced);
}

void RootIndex::insert(RowHandle *rh)
{
	type_->groupInsert(rootg_, rh);
}

void RootIndex::remove(RowHandle *rh)
{
	type_->groupRemove(rootg_, rh);
}

void RootIndex::aggregateBefore(const RhSet &rows, const RhSet &already, Tray *copyTray)
{
	type_->groupAggregateBefore(table_, rootg_, rows, already, copyTray);
}

void RootIndex::aggregateAfter(Aggregator::AggOp aggop, const RhSet &rows, const RhSet &future, Tray *copyTray)
{
	type_->groupAggregateAfter(aggop, table_, rootg_, rows, future, copyTray);
}

size_t RootIndex::size()
{
	return type_->groupSize(rootg_);
}

bool RootIndex::collapse(const RhSet &replaced, Tray *copyTray)
{
	// fprintf(stderr, "DEBUG RootIndex::collapse(this=%p, rhset size=%d) rootg_=%p\n", this, (int)replaced.size(), rootg_);
	if (rootg_ == NULL)
		return true;
	type_->groupCollapse(rootg_, replaced, copyTray);
	return false; // the root index never collapses its group
}

}; // BICEPS_NS
