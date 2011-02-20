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

const char *Rowop::opcodeString(Opcode code)
{
	switch(code) {
	case OP_NOP:
		return "NOP";
	case OP_INSERT:
		return "INSERT";
	case OP_DELETE:
		return "DELETE";
	default:
		// for the unknown opcodes, get at least the general sense
		if (isInsert(code) && isDelete(code))
			return "[ID]";
		else if (isInsert(code))
			return "[I]";
		else if (isDelete(code))
			return "[D]";
		else
			return "[NOP]";
	}
}

}; // BICEPS_NS
