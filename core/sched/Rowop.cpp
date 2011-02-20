//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Encapsulation of a row operation.

#include <sched/Rowop.h>
#include <sched/Label.h>

namespace BICEPS_NS {

Rowop::Rowop(const Label *label, Opcode op, Onceref<Row> row) :
	label_(label),
	row_(row),
	opcode_(op)
{
	assert(label);
	if (row_)
		row_->incref(); // manual reference keeping
}

Rowop::Rowop(const Label *label, Opcode op, const Rowref &row) :
	label_(label),
	row_(row),
	opcode_(op)
{
	assert(label);
	if (row_)
		row_->incref(); // manual reference keeping
}


Rowop::~Rowop()
{
	if (row_) {
		if (row_->decref() <= 0)
			label_->getType()->destroyRow(row_);
	}
}


}; // BICEPS_NS
