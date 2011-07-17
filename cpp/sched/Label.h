//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// CEP code label.

#ifndef __Triceps_Label_h__
#define __Triceps_Label_h__

#include <mem/Autoref.h>
#include <mem/Starget.h>

namespace TRICEPS_NS {

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
	Label(Unit *unit, const_Onceref<RowType> rtype, const string &name = "");
	
	virtual ~Label();

	// Get the type of rows handled here
	const RowType *getType() const
	{
		return type_;
	}

	Unit *getUnit() const
	{
		return unit_;
	}

	// Chain another label to this one.
	// Checks for correct row types and for direct loops.
	// Note that it still would not detect loops with connections through the input
	// and output labels of a table or such.
	//
	// @param lab - other label to chain here
	// @return - NULL ref if chained successfully, otherwise an error indication
	Erref chain(Onceref<Label> lab);

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

	// XXX any reason to change name after construction?
	void setName(const string &name)
	{
		name_ = name;
	}

	// Clear this label's references. 
	// The topology of inter-label connections may include loops
	// (not necessarily as chains, but through the user labels and
	// user logic).  If each label has a reference to the next one, 
	// that would create a circular reference, and on destruction the
	// labels will never be freed. So the Unit keeps track of all the 
	// labels in it, and eventually requests them to clear their stuff,
	// thus breaking the circular dependency.
	// The base class implementation is to call clearChained() and set
	// the cleared flag.
	// If the subclasses redefine this method (and if there are any
	// references in them, they should), they still must call
	// the parent's method.
	virtual void clear();

	// Check the cleared flag. This flag means that the program is in the
	// destruction stage, and the Unit has already logically went away,
	// so no future work must be done.
	bool isCleared() const
	{
		return cleared_;
	}

protected:
	// The subclasses re-define this method to do something useful.
	//
	// arg - operation to perform; the caller holds a reference on it.
	virtual void execute(Rowop *arg) const = 0;

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
	void call(Unit *unit, Rowop *arg, const Label *chainedFrom = NULL) const;

	// Check for circular dependencies when adding a label.
	// Goes recursively through all the chained labels reachable from
	// here and looks for the target label. If found, builds a path
	// of how it's reachable. Since it's called recursively, on success
	// each call adds its step of the path to the end of trace, and
	// when the outermost call returns, the path contains the whole
	// dependency list in backwards order.
	//
	// @param target - label to look for
	// @param path - if target found, will have the path to target appended
	//        (so normally should be passed as an empty list to the outermost call)
	// @return - true if found
	bool findChained(const Label *target, ChainedVec &path) const;
	
protected:
	ChainedVec chained_; // the chained labels
	const_Autoref<RowType> type_; // type of the row handled here
	Unit *unit_; // not a reference, but more of a token
	string name_; // human-readable name for tracing
	bool cleared_; // flag: clear() was called, and the label should stop working
};

// A label that does nothing: typically used as an endpoint for chaining in the 
// tables and such.
class DummyLabel : public Label
{
public:
	DummyLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name = "") :
		Label(unit, rtype, name)
	{ }

protected:
	// from Label
	virtual void execute(Rowop *arg) const;
};

}; // TRICEPS_NS

#endif // __Triceps_Label_h__
