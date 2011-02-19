//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The table implementation.

#include <table/Table.h>
#include <type/TableType.h>
#include <type/RootIndexType.h>

namespace BICEPS_NS {

Table::Table(const TableType *tt, const RowType *rowt, const RowHandleType *handt, const IndexTypeVec &topIt) :
	type_(tt),
	rowType_(rowt),
	rhType_(handt)
{ 
	root_ = static_cast<RootIndex *>(tt->root_->makeIndex(tt, this));
	// fprintf(stderr, "DEBUG Table::Table root=%p\n", root_.get());
}

Table::~Table()
{
	// fprintf(stderr, "DEBUG Table::~Table root=%p\n", root_.get());

	// remove all the rows in the table: this goes more efficiently
	// if we first move them to a vector, clear the indexes and delete from vector;
	// otherwise the index rebalancing during deletion takes a much longer time
	vector <RowHandle *> rows;
	rows.reserve(root_->size());

	{
		RowHandle *rh;
		for (rh = root_->begin(); rh != NULL; rh = root_->next(rh))
			rows.push_back(rh);
	}

	root_->clearData();

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
	type_->root_->initRowHandle(rh);

	return rh;
}

void Table::destroyRowHandle(RowHandle *rh)
{
	// for each index, clear whatever per-handle internal objects there may be
	type_->root_->clearRowHandle(rh);
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

bool Table::insert(RowHandle *newrh)
{
	if (newrh == NULL)
		return false;

	if (newrh->isInTable())
		return false;  // nothing to do

	Index::RhSet replace;

	if (!root_->replacementPolicy(newrh, replace)) {
		// this may have created the groups for the new record that didn't get inserted, so collapse them back
		replace.insert(newrh);
		root_->collapse(replace);
		return false;
	}

	// delete the rows that are pushed out but don't collapse the groups yet
	for (Index::RhSet::iterator rsit = replace.begin(); rsit != replace.end(); ++rsit) {
		RowHandle *rh = *rsit;
		root_->remove(rh);
		rh->flags_ &= ~RowHandle::F_INTABLE;
	}

	// now keep the table-wide reference to that new handle
	newrh->incref();
	newrh->flags_ |= RowHandle::F_INTABLE;

	root_->insert(newrh);

	// finally, collapse the groups
	root_->collapse(replace);

	// and then the removed rows get unreferenced by the table
	// XXX these rows should also be returned in a tray
	for (Index::RhSet::iterator rsit = replace.begin(); rsit != replace.end(); ++rsit) {
		RowHandle *rh = *rsit;
		if (rh->decref() <= 0)
			destroyRowHandle(rh);
	}
	
	return true;
}

void Table::remove(RowHandle *rh)
{
	if (rh == NULL || !rh->isInTable())
		return;

	root_->remove(rh);
	rh->flags_ &= ~RowHandle::F_INTABLE;

	Index::RhSet replace;
	replace.insert(rh);
	root_->collapse(replace);
	
	if (rh->decref() <= 0)
		destroyRowHandle(rh);
}

RowHandle *Table::begin() const
{
	return root_->begin();
}

RowHandle *Table::next(const RowHandle *cur) const
{
	return root_->next(cur);
}

RowHandle *Table::nextGroup(IndexType *ixt, const RowHandle *cur) const
{
	return NULL; // XXX to be figured out
}

RowHandle *Table::find(IndexType *ixt, const RowHandle *what) const
{
	if (ixt == NULL || ixt->getTabtype() != type_)
		return NULL;

	return ixt->findRecord(this, what);
}

}; // BICEPS_NS

