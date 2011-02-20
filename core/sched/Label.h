//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// CEP code label.

#ifndef __Biceps_Label_h__
#define __Biceps_Label_h__

#include <mem/Autoref.h>
#include <mem/Starget.h>

namespace BICEPS_NS {

class Rowop;
class Unit;
class RowType;

// A label provides a way to call some user-defined code to handle an event.
// This works by subclassing: define your own subclass and define the method 
// execute() in it that does what you need. It's a functor object.
// A label handles the rows of only one type.
// A label belongs to exactly one execution Unit. If you need to do the same
// processing in multiple units, make a separate instance of your label
// subclass for each unit.
//
// The labels may be chained together: after a label executes its own handling
// code, it may call the other labels on the same input row.
// The chaining is a common idiom used by the tables and other state-keeping
// elements: a table defines its own output label with empty handling code where
// it sends the information about updates in the table. To receive these updates,
// the user may define his own labels and chain them to the table's label.
// Similarly a table defines its input label. The user can then chain that input
// label to other labels and make the table automatically receive the updates.
class Label : public Starget
{
public:
	typedef vector<Autoref<Label> > ChainedVec; 

	// @param unit - the unit where this label belongs
	// @param rtype - type of row to be handled by this label
	// @param name - a human-readable name of this label, for tracing
	Label(Unit *unit, Onceref<RowType> rtype, const string &name = "");
	
	virtual ~Label();

	// Get the type of rows handled here
	RowType *getType() const
	{
		return type_;
	}

	// Chain another label to this one.
	// Be careful, you can create the endless loops by chaining in a circular fashion!
	//
	// XXX add a check for circular chains, and better error reporting
	//
	// @param lab - other label to chain here
	// @return - true if chained successfully, false if the row type is not equal
	bool chain(Onceref<Label> lab);

	// Clear the chain leading from this label.
	void clearChained();

	// Get the chain leading from this label.
	const ChainedVec &getChain()
	{
		return chained_;
	}

	// Get the human-readable name
	const string &getName() const
	{
		return name_;
	}

	void setName(const string &name)
	{
		name_ = name;
	}

protected:
	// The subclasses re-define this method to do something useful.
	//
	// arg - operation to perform; the caller holds a reference on it.
	virtual void execute(const Rowop *arg) const = 0;

protected:
	friend class Unit;

	// This fuction is called by the Unit to perform the execution,
	// including all the chaining. A Label can not be called directly,
	// but only through its Unit.
	//
	// The Unit is expected to have pushed a new frame into the stack
	// before calling here. This method drains the frame.
	//
	// unit - unit from where called (should be the same as in constructor)
	// arg - operation to perform; the caller holds a reference on it.
	// chainedFrom - if this call is a result of chaining, the chain parent
	void call(Unit *unit, const Rowop *arg, const Label *chainedFrom = NULL) const;

protected:
	ChainedVec chained_; // the chained labels
	Autoref<RowType> type_; // type of the row handled here
	Unit *unit_; // not a reference, but more of a token
	string name_; // human-readable name for tracing
};

// A label that does nothing: typically used as an endpoint for chaining in the 
// tables and such.
class DummyLabel : public Label
{
public:
	DummyLabel(Unit *unit, Onceref<RowType> rtype, const string &name = "") :
		Label(unit, rtype, name)
	{ }

protected:
	// from Label
	virtual void execute(const Rowop *arg) const;
};

}; // BICEPS_NS

#endif // __Biceps_Label_h__
