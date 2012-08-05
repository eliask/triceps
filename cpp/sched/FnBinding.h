//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Binding of a streaming function return to a set of concrete labels.

#ifndef __Triceps_FnBinding_h__
#define __Triceps_FnBinding_h__

#include <type/RowSetType.h>
#include <sched/Label.h>

namespace TRICEPS_NS {

class FnReturn;

// This defines the "return point" for a concrete call of a streaming
// function. It binds the labels int the function's return set to
// the concrete labels provided by the caller.
class FnBinding : public Starget
{
public:
	// The typical construction is done as a chain:
	// ret = FnBinding::make(fn)
	//     ->addLabel("lb1", lb1)
	//     ->addLabel("lb2", lb2);
	//
	// Or to throw on errors:
	// ret = FnBinding::make(fn)
	//     ->addLabel("lb1", lb1)
	//     ->addLabel("lb2", lb2)
	//     ->checkOrThrow();
	//
	// @param fn - the return of the function to bind to. Must be initialized.
	FnBinding(FnReturn *fn);
	
	// The convenience wharpper for the constructor
	static FnBinding *make(FnReturn *fn)
	{
		return new FnBinding(fn);
	}

	// Add a label to the binding. Any errors found can be read
	// later with getErrors(). The repeated bindings to the same
	// name are considered errors.
	//
	// This does not check for the label loops because that would not
	// cover all the possible mess-ups anyway. But you still must not
	// attempt to create the tight loops, or they will be caught at
	// run time.
	//
	// It is OK for the labels in the FnBinding be from a different
	// Unit than in FnReturn.
	//
	// @param name - name of the element in the return to bind to
	// @param lb - label to bind. Must have a matching row type.
	//        The binding will keep a reference to that label.
	// @return - the same FnBinding object, for chained calls.
	FnBinding *addLabel(const string &name, Autoref<Label> lb);

	// Get the collected error info. A binding with errors should
	// not be used for calls.
	Erref getErrors() const
	{
		return errors_;
	}

	// Checks for errors and throws an Exception if any are found.
	// Takes care of the memory consistency on throwing by increasing
	// and decreasing the ref count on this object, so that if it hasn't
	// been stored in an Autoref yet, it will get destroyed.
	// @return - the same FnBinding object, for chained calls.
	FnBinding *checkOrThrow();

	// Get back the label by index. Mostly for the benefit of FnReturn.
	// @param idx - index of the label
	// @return - the label pointer or NULL if that label is not defined
	Label *getLabel(int idx) const;

protected:
	typedef vector<Autoref<Label> > LabelVec; 

	Autoref<RowSetType> type_; // type of FnReturn
	LabelVec labels_; // reached by index
	Erref errors_; // the accumulated errors
};

}; // TRICEPS_NS

#endif // __Triceps_FnBinding_h__

