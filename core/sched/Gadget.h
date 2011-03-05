//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A basic stateful element inside a Unit.

#ifndef __Biceps_Gadget_h__
#define __Biceps_Gadget_h__

#include <sched/Unit.h>

namespace BICEPS_NS {

// A Gadget is something with its own mind, which in response to
// operations on it may produce records and enqueues them to the Unit's
// scheduler. A Gadget has its own dummy label for those records,
// so that processing can be chained from it. Duplicates of these
// records can also be collected on a Tray.
// A Table is a concrete example of Gadget.
//
// Gadgets are a part of Unit, so Starget is good enough.
class Gadget : public Starget
{
public:
	// How the rows get enqueued in the Unit
	enum EnqMode {
		SM_SCHEDULE,
		SM_FORK,
		SM_CALL,
		SM_IGNORE, // rows aren't equeued at all
	};

	virtual ~Gadget();

	// Get back the enqueueing mode
	EnqMode getEnqMode() const
	{
		return mode_;
	}
	
	// Get back the name
	const string &getName() const
	{
		return name_;
	}

	// Get the unit
	Unit *getUnit() const
	{
		return unit_;
	}

	// Get the label where the rowops will be sent to.
	// (Gadget is normally not going anywhere, so returning a pointer is OK).
	// @return - the label after it was initialized, or NULL before that
	Label *getLabel() const
	{
		return label_;
	}

protected:
	// interface for subclasses

	// @param unit - Unit where the gadget belongs
	// @param mode - how the rowops will be enqueued
	// @parem name - name of the gadget if known, will be used to name the label
	// @param rt - row type produced by this gadget, or NULL if not known yet
	Gadget(Unit *unit, EnqMode mode, const string &name = "", const_Onceref<RowType> rt = (const RowType*)NULL);

	// Change the enqueueing mode.
	void setEnqMode(EnqMode mode)
	{
		mode_ = mode;
	}

	// Change the gadget's name (the label won't be changed until setRowType()).
	void setName(const string &name)
	{
		name_ = name;
	}

	// Set the row type. This initializes the label.
	void setRowType(const_Onceref<RowType> rt);

	// Send a row.
	// By this time the row type must be set, and so the embedded label initialized
	// (even if the mode is SM_IGNORE).
	//
	// If the user requests a copy, he should not try to schdeule it as is, since
	// that would repeat the change the second time. Instead he should either do a
	// translation on that tray or pick the records individually.
	//
	// @param row - row being sent, may be NULL which will be ignored and produce nothing
	// @param opcode - opcode for rowop
	// @param copyTray - tray to insert a copy of the row, or NULL
	// XXX later will add timestamp and sequence
	void send(const Row *row, Rowop::Opcode opcode, Tray *copyTray);

protected:
	Autoref<Unit> unit_; // unit where it belongs (not that Unit doesn't have a ref back, ao Autoref is OK)
	Autoref<Label> label_; // this gadget's label
	const_Autoref<RowType> type_; // type of rows
	string name_; // name of the gadget, passed to the label name
	EnqMode mode_; // how the rowops get enqueued in unit

private:
	Gadget(const Gadget &);
	void operator=(const Gadget &);
};

// a version that exports setEnqMode()
// (CS stands for Changeable Enqueueing)
class GadgetCE : public Gadget
{
public:
	GadgetCE(Unit *unit, EnqMode mode, const string &name = "", Onceref<RowType> rt = (RowType*)NULL) :
		Gadget(unit, mode, name, rt)
	{ }

	void setEnqMode(EnqMode mode)
	{
		mode_ = mode;
	}
};

}; // BICEPS_NS

#endif // __Biceps_Gadget_h__
