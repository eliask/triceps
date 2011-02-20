//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Encapsulation of a row operation.

#ifndef __Biceps_Rowop_h__
#define __Biceps_Rowop_h__

#include <type/RowType.h>
#include <mem/Starget.h>

namespace BICEPS_NS {

class Label;
class Row;
class Rowref;

// A row operation provides the basic scheduling element for the execution
// unit. It ties together the row argument (may be NULL in some special cases),
// the opcode, additional information such as timestamp and sequence number,
// and the label to call for handling of the row.
// The rowops are fundamentally tied to an execution Unit, so they live
// withing a single thread. They can not be directly passed between two execution
// units even in a single thread, instead they mush be translated. Similarly,
// they need to be translated for passing to a unit inside another thread.
class Rowop : public Starget
{
public:
	enum OpcodeFlags {
		// Each opcode has the flags in the lower 2 bits, classifying it.
		// This allows some labels to act based on this crude classification,
		// without goin into the deeper opcode details. The classification is:
		//   0 - a NOP
		//   INSERT - insert a row, also used for generally passing the rows around
		//   DELETE - delete a row, generally undoing a previous action
		//   (INSERT|DELETE) - currently not defined and may cause random effects
		OCF_INSERT = 0x01,
		OCF_DELETE = 0x02
	};

	enum Opcode {
		OP_NOP = 0,
		OP_INSERT = OCF_INSERT,
		OP_DELETE = OCF_DELETE
	};

	// Rowop will hold the references on the row and the label.
	Rowop(const Label *label, Opcode op, Onceref<Row> row);
	Rowop(const Label *label, Opcode op, const Rowref &row);

	~Rowop();

	Opcode getOpcode() const 
	{
		return opcode_;
	}

	// get the curde classification
	static bool isInsert(Opcode op)
	{
		return (op & OCF_INSERT);
	}
	static bool isDelete(Opcode op)
	{
		return (op & OCF_DELETE);
	}
	bool isInsert() const
	{
		return isInsert(opcode_);
	}
	bool isDelete() const
	{
		return isDelete(opcode_);
	}

	const Label *getLabel() const
	{
		return  label_;
	}

	Row *getRow() const
	{
		return row_;
	}

protected:
	Autoref<const Label> label_;
	Row *row_; // a manual reference, the type from Label will be used for deletion
	// no timestamp nor sequence now, these will come later
	Opcode opcode_;
};

}; // BICEPS_NS

#endif // __Biceps_Rowop_h__
