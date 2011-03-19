//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Encapsulation of a row operation.

#include <sched/Rowop.h>
#include <sched/Label.h>
#include <sched/Gadget.h>

namespace BICEPS_NS {

Rowop::Rowop(const Label *label, Opcode op, const Row *row) :
	label_(label),
	row_(row),
	opcode_(op),
	enqMode_(Gadget::SM_FORK)
{
	assert(label);
	if (row_)
		row_->incref(); // manual reference keeping
}

Rowop::Rowop(const Label *label, Opcode op, const Rowref &row) :
	label_(label),
	row_(row),
	opcode_(op),
	enqMode_(Gadget::SM_FORK)
{
	assert(label);
	if (row_)
		row_->incref(); // manual reference keeping
}

Rowop::Rowop(const Label *label, Opcode op, const Row *row, int enqMode) :
	label_(label),
	row_(row),
	opcode_(op),
	enqMode_(enqMode)
{
	assert(label);
	if (row_)
		row_->incref(); // manual reference keeping
}

Rowop::Rowop(const Label *label, Opcode op, const Rowref &row, int enqMode) :
	label_(label),
	row_(row),
	opcode_(op),
	enqMode_(enqMode)
{
	assert(label);
	if (row_)
		row_->incref(); // manual reference keeping
}

Rowop::Rowop(const Rowop &orig) :
	label_(orig.getLabel()),
	row_(orig.getRow()),
	opcode_(orig.getOpcode()),
	enqMode_(orig.getEnqMode())
{
	if (row_)
		row_->incref(); // manual reference keeping
}

Rowop::~Rowop()
{
	if (row_) {
		if (row_->decref() <= 0)
			label_->getType()->destroyRow(const_cast<Row *>(row_));
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
