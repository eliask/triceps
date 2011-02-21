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
// operations on it may produce records and send them to the Unit's
// scheduler. A Gadget has its own dummy label for those records,
// so that processing can be chained from it. Duplicates of these
// records can also be collected on a Tray.
// A Table is a concrete example of Gadget.
//
// Each concrete subclass is free to decide if it wants to be
// an Starget or Mtarget.
class Gadget 
{
public:
	// How the rows get scheduled in the Unit
	enum SchedMode {
		SM_SCHEDULE,
		SM_FORK,
		SM_CALL,
		SM_IGNORE, // rows aren't scheduled at all
	};

	virtual ~Gadget();

	// Get back the scheduling mode
	SchedMode getSchedMode() const
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
	Label *getSchedLabel() const
	{
		return label_;
	}

protected:
	// interface for subclasses

	// @param unit - Unit where the gadget belongs
	// @param mode - how the rowops will be scheduled
	// @parem name - name of the gadget if known, will be used to name the label
	// @param rt - row type produced by this gadget, or NULL if not known yet
	Gadget(Unit *unit, SchedMode mode, const string &name = "", Onceref<RowType> rt = (RowType*)NULL);

	// Change the scheduling mode.
	void setSchedMode(SchedMode mode)
	{
		mode_ = mode;
	}

	// Change the gadget's name (the label won't be changed until setRowType()).
	void setName(const string &name)
	{
		name_ = name;
	}

	// Set the row type. This initializes the label.
	void setRowType(Onceref<RowType> rt);

	// Send a row.
	// By this time the row type must be set, and so the embedded label initialized
	// (even if the mode is SM_IGNORE).
	//
	// @param row - row being sent, may be NULL which will be ignored
	// @param opcode - opcode for rowop
	// @param copyTray - tray to insert a copy of the row
	// @param copyLabel - the label for the copy (must not be NULL if copyTray is not NULL);
	//        MUST be of an equal row type (checking left to the caller).
	// XXX later will add timestamp and sequence
	void send(Row *row, Rowop::Opcode opcode, Tray *copyTray, Label *copyLabel);

protected:
	Autoref<Unit> unit_; // unit where it belongs (not that Unit doesn't have a ref back, ao Autoref is OK)
	Autoref<Label> label_; // this gadget's label
	Autoref<RowType> type_; // type of rows
	string name_; // name of the gadget, passed to the label name
	SchedMode mode_; // how the rowops get scheduled in unit
};

// a version that exports setSchedMode()
// (CS stands for Changeable Scheduling)
class GadgetCS : public Gadget
{
public:
	GadgetCS(Unit *unit, SchedMode mode, const string &name = "", Onceref<RowType> rt = (RowType*)NULL) :
		Gadget(unit, mode, name, rt)
	{ }

	void setSchedMode(SchedMode mode)
	{
		mode_ = mode;
	}
};

}; // BICEPS_NS

#endif // __Biceps_Gadget_h__
