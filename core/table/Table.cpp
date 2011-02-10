//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The table implementation.

#include <table/Table.h>
#include <type/TableType.h>

namespace BICEPS_NS {

Table::Table(const TableType *tt, const RowType *rowt, const RowHandleType *handt, const IndexTypeVec &topIt) :
	type_(tt),
	rowType_(rowt),
	rhType_(handt),
	size_(0)
{ 
	tt->topInd_.makeIndexes(tt, this, &topInd_);
}

Table::~Table()
{
	// remove all the rows in the table: this goes more efficiently
	// if we first move them to a vector, clear the indexes and delete from vector;
	// otherwise the index rebalancing during deletion takes a much longer time
	vector <RowHandle *> rows;
	rows.reserve(size_);

	if (!topInd_.empty()) {
		RowHandle *rh;
		Index *index = topInd_[0].index_;
		for (rh = index->begin(); rh != NULL; rh = index->next(rh))
			rows.push_back(rh);
	}

	topInd_.clearData();

	for (vector <RowHandle *>::iterator it = rows.begin(); it != rows.end(); ++it) {
		RowHandle *rh = *it;
		rh->flags_ &= ~RowHandle::F_INTABLE;
		if (rh->decref() <= 0)
			destroyRowHandle(rh);
	}
}

RowHandle *Table::makeRowHandle(const Row *row)
{
	if (row == NULL)
		return NULL;

	row->incref();
	RowHandle *rh = rhType_->makeHandle(row);
	// for each index, fill in the cached key information
	topInd_.initRowHandle(rh);

	return rh;
}

void Table::destroyRowHandle(RowHandle *rh)
{
	// for each index, clear whatever per-handle internal objects there may be
	topInd_.clearRowHandle(rh);
	Row *row = const_cast<Row *>(rh->row_);
	if (row->decref() <= 0)
		rowType_->destroyRow(row);
	delete rh;
}

bool Table::insert(const Row *row)
{
	if (row == NULL)
		return false;

	RowHandle *rh = makeRowHandle(row);
	rh->incref();

	bool res = insert(rh);

	if (rh->decref() <= 0)
		destroyRowHandle(rh);

	return res;
}

bool Table::insert(RowHandle *rh)
{
	if (rh == NULL)
		return false;

	if (rh->isInTable())
		return false;  // nothing to do

	Index::RhSet replace;

	if (!topInd_.replacementPolicy(rh, replace))
		return false;

	// delete the records that are pushed out
	// XXX these records should also be returned in a tray
	for (Index::RhSet::iterator rsit = replace.begin(); rsit != replace.end(); ++rsit)
		remove(*rsit);

	topInd_.insert(rh);

	// now keep the table-wide reference to that handle
	rh->incref();
	rh->flags_ |= RowHandle::F_INTABLE;
	++size_;

	return true;
}

void Table::remove(RowHandle *rh)
{
	if (rh == NULL || !rh->isInTable())
		return;

	topInd_.remove(rh);
	
	rh->flags_ &= ~RowHandle::F_INTABLE;
	if (rh->decref() <= 0)
		destroyRowHandle(rh);
	--size_;
}

RowHandle *Table::begin() const
{
	if (topInd_.empty())
		return NULL;
	return topInd_[0].index_->begin();
}

RowHandle *Table::next(RowHandle *cur) const
{
	if (topInd_.empty())
		return NULL;
	return topInd_[0].index_->next(cur);
}

}; // BICEPS_NS

