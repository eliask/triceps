//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Representation of a streaming function return.

#ifndef __Triceps_FnReturn_h__
#define __Triceps_FnReturn_h__

#include <type/RowSetType.h>
#include <sched/Label.h>
#include <sched/FnBinding.h>

namespace TRICEPS_NS {

// The concept of the streaming function is:
// You call some label(s), that performs some streaming computations and 
// produces the result on some other labels. Before you do the call, you
// connect these result labels with some other labels that would handle
// the result. It's like pushing the return address of a common function
// call onto the stack: tells, where to continue with handling of the
// function results after it returns. Unlike the common function call,
// the streaming function may produce multiple result rowops on its result
// labels, and normally the return handlers would be called for them
// right when they are produced, without waiting for the complete function
// return.
//
// FnReturn describes the set of return labels of a streaming function.
// Each of them has a name (by which the handler can be collected later)
// and may be immediately chained to another label on creation.
//
// Since all the labels are single-threaded, the return value is single-
// threaded too.
class FnReturn: public Starget
{
protected:
	// The class of labels created inside FnReturn, that forward the rowops
	// to the final destination.
	class RetLabel : public Label
	{
	public:
		// @param unit - the unit where this label belongs
		// @param rtype - type of row to be handled by this label
		// @param name - a human-readable name of this label, for tracing
		// @param fnret - FnReturn where this label belongs
		// @param idx - index of this label in FnReturn
		RetLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name,
			FnReturn *fnret, int idx);

	protected:
		// from Label
		virtual void execute(Rowop *arg) const;

		FnReturn *fnret_; // not a ref, to avoid cyclic refs
		int idx_; // index in fnret_ to which to forward
	};

public:
	// representation of the labels in this return
	typedef vector<Autoref<RetLabel> > ReturnVec;
	// representation of the call stack
	typedef vector<Autoref<FnBinding> > BindingVec;

	// The typical construction is done as a chain:
	// ret = FnReturn::make(unit, name)
	//     ->addLabel("lb1", rt1)
	//     ->addFromLabel("lb2", lbX)
	//     ->initialize();
	//
	// Or with throwing on errors:
	// ret = FnReturn::make(unit, name)
	//     ->addLabel("lb1", rt1)
	//     ->addFromLabel("lb2", lbX)
	//     ->initializeOrThrow();
	//
	// @param unit - the unit where this return belongs
	// @param name - a human-readable name of this return set
	FnReturn(Unit *unit, const string &name);

	// The convenience wharpper for the constructor
	static FnReturn *make(Unit *unit, const string &name)
	{
		return new FnReturn(unit, name);
	}

	// Get back the name.
	const string &getName() const
	{
		return name_;
	}

	// Add a label to the result. Any errors will be remembered and
	// reported during initialization.
	// Maybe used only until initialized.
	//
	// Technically, a RetLabel label gets created in the FnReturn,
	// having the same type as the argument label, and getting
	// chained to that argument label.
	//
	// Adding multiple copies of the same label is technically legal
	// but achieves nothing useful, just multiple aliases.
	//
	// @param lname - name, by which this label can be connected later;
	//        the actual label name will be return-name.label-name
	// @param from - a label, from which the row type will be taken, 
	//        and to which the result label will be chained.
	//        Must belong to the same unit (or error will be remembered).
	// @return - the same FnReturn object, for chained calls.
	FnReturn *addFromLabel(const string &lname, Autoref<Label>from);
	
	// Add a RetLabel to the result. Any errors will be remembered and
	// reported during initialization.
	// Maybe used only until initialized.
	//
	// @param lname - name, by which this label can be connected later;
	//   the actual label name will be return-name.label-name
	// @param rtype - row type for the label
	// @return - the same FnReturn object, for chained calls.
	FnReturn *addLabel(const string &lname, const_Autoref<RowType>rtype);

	// Check all the definition and derive the internal
	// structures. The result gets returned by getErrors().
	// May be called repeatedly with no ill effects.
	// @return - the same FnReturn object, for chained calls.
	FnReturn *initialize()
	{
		type_->freeze();
		initialized_ = true;
		return this;
	}

	// Just like initialize() but any errors found get thrown
	// in an Exception.
	// Takes care of the memory consistency on throwing by increasing
	// and decreasing the ref count on this object, so that if it hasn't
	// been stored in an Autoref yet, it will get destroyed.
	// May be called repeatedly with no ill effects.
	FnReturn *initializeOrThrow();

	// Whether it was already initialized
	bool isInitialized() const
	{
		return initialized_;
	}

	// Get the type. Works only after initialization. Throws an
	// Exception before then.
	RowSetType *getType() const;

	// Get all the errors detected during construction.
	Erref getErrors() const
	{
		return type_->getErrors();
	}
	// Get the number of labels
	int size() const
	{
		return labels_.size();
	}

	// Propagation from type_.
	const RowSetType::NameVec &getLabelNames() const
	{
		return type_->getRowNames();
	}
	const RowSetType::RowTypeVec &getRowTypes() const
	{
		return type_->getRowTypes();
	}
	const string *getLabelName(int idx) const
	{
		return type_->getRowTypeName(idx);
	}
	RowType *getRowType(const string &name) const
	{
		return type_->getRowType(name);
	}
	RowType *getRowType(int idx) const
	{
		return type_->getRowType(idx);
	}
	// XXX is there any use in returning the array of labels?

	// This is technically not a type but these are convenient wrappers to
	// compare the equality of the underlying row set types.
	bool equals(const FnReturn *t) const;
	bool match(const FnReturn *t) const;

	// Get a label by name.
	// @param name - the name of the label, as was specified in addLabel()
	// @return - the label, or NULL if not found
	Label *getLabel(const string &name) const;
	
	// Translate the label name to its index in the internal array. This index
	// can later be used to get the label quickly.
	// @param name - the name of the label, as was specified in addLabel()
	// @return - the index, or -1 if not found
	int findLabel(const string &name) const;

	// Get a label by its index in the internal array.
	// @param idx - the name of the label, as was specified in addLabel()
	// @return - the label, or NULL if not found
	Label *getLabel(int idx) const;

	// Get back the set of labels.
	const ReturnVec &getLabels() const
	{
		return labels_;
	}

	// Push a binding onto the "call stack". The binding on the top
	// of the stack will be used to forward the rowops.
	// Throws an Exception if not initialized.
	//
	// @param bind - the binding. Must be of a matching type or may
	//        crash if it's not.
	void push(Onceref<FnBinding> bind);
	// Pop a binding from the top of the stack.
	// Throws an Exception if the stack is empty.
	void pop();
	// Pop a binding from the top of the stack and check that it
	// matches the expected ones. If it doesn't match, will throw
	// an Exception. Useful for diagnostics of incorrect push-pop sequences.
	// @param bind - the expected binding.
	void pop(Onceref<FnBinding> bind);

	// Mostly for diagnostics: get the binding stack size.
	int bindingStackSize() const
	{
		return stack_.size();
	}

	// mostly for diagnostics: get the binding stack
	const BindingVec &bindingStack() const
	{
		return stack_;
	}

protected:
	Unit *unit_; // not a reference, used only to create the labels
	string name_; // human-readable name, and base for the label names
	Autoref<RowSetType> type_;
	ReturnVec labels_; // the return labels, same size as the type
	BindingVec stack_; // the top of call stack is the end of vector
	bool initialized_; // flag: has already been initialized, no more changes allowed
};

// Bind and unbind a return as a scope:
// push on object creation, pop on object deletion.
// {
//     ScopeFnBind autobind(ret, binding);
//     ...
// }
class ScopeFnBind
{
public:
	// Pushes the binding on construction.
	ScopeFnBind(Onceref<FnReturn> ret, Onceref<FnBinding> binding);
	// Pops the binding on destruction.
	// May throw an Exception if the binding stack got messed up.
	~ScopeFnBind();

protected:
	Autoref<FnReturn> ret_;
	Autoref<FnBinding> binding_;
};

// Bind and unbind multiple returns as a group, and maintain the set
// by reference (this allows it to be used from Perl).
// The typical use (provided that all the calls are correct):
// {
//     Autoref<MultiFnBind> bind = MultiFnBind::make()
//         ->add(ret1, binding1)
//         ->add(ret2, binding2);
//     ...
// }
// But if add() might throw, that would leave a memory leak of the
// MultiFnBind object. Then assign it to an Autoref first, and call
// add() later:
// {
//     Autoref<MultiFnBind> bind = new MultiFnBind;
//     bind
//         ->add(ret1, binding1)
//         ->add(ret2, binding2);
//     ...
// }
class MultiFnBind: public Starget
{
public:
	// The default constructor works good enough.
	
	// Pops the binding on destruction.
	// If the stack order got disrupted, this may throw an Exception.
	// Which is OK for the C++ programs with the default exception handling
	// by abort(). If not aborting, an exception from a destructor is
	// a Bad Thing. In this case (such as in the scripting language wrappers)
	// should call clear() first, process the exceptions if any, and only
	// then destroy.
	~MultiFnBind();

	// Pop the bindings and forget about them.
	// If the stack order got disrupted, this may throw an Exception.
	// It will go through all the elements, doing pop() for each of them,
	// and catching the exceptions. Then all the bindings information
	// will be cleared. Then if any exceptions were caught,
	// a new exception will be thrown with all the collected info.
	void clear();

	// a convenience factory, more convenient to use than parenthesis
	// around the new statement
	static MultiFnBind *make()
	{
		return new MultiFnBind;
	}

	// push a binding, and remember it for popping
	// @param ret - return to push onto
	// @param binding - binding to push
	// @return - the same MultiFnBind object, for chained calls
	MultiFnBind *add(Onceref<FnReturn> ret, Autoref<FnBinding> binding);

protected:
	vector<Autoref<FnReturn> > rets_;
	vector<Autoref<FnBinding> > bindings_;
};

}; // TRICEPS_NS

#endif // __Triceps_FnReturn_h__

