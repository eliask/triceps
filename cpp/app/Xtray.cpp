//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A tray for passing the rowops across the nexuses.

#include <app/Xtray.h>

namespace TRICEPS_NS {

Xtray::Xtray(RowSetType *rst):
	type_(rst)
{ }

Xtray::~Xtray()
{
	for (OpVec::iterator it = ops_.begin(); it != ops_.end(); ++it) {
		Row *row = it->row_;
		if (row) {
			if (row->decref() <= 0) // manual reference keeping
				type_->getRowType(it->idx_)->destroyRow(row);
		}
	}
}

void Xtray::push_back(const Op &data)
{
	Row *row = data.row_;
	ops_.push_back(data);
	if (row)
		row->incref(); // manual reference keeping
}

}; // TRICEPS_NS
