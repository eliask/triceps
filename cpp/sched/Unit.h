//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The basic execution unit.

#ifndef __Triceps_Unit_h__
#define __Triceps_Unit_h__

#include <common/Common.h>
#include <sched/Tray.h>
#include <sched/Label.h>
#include <list>

namespace TRICEPS_NS {

// The basic execution unit ties together a buch of tables, code and scheduling.
// It lives inside one thread and always executes sequentially. But nothing really
// stops a thread from having multiple execution units in it.
//
// The scheduling queue is composed of nested frames. The next rowop to execute is
// always taken from the front of the innermost frame. If a rowop is completed
// and its frame is found empty, the frame gets popped. The outermost frame
// is never popped from the stack even when it's completely empty.
//
// There are 3 ways to add rowops to the queue:
// 1. To the tail of the outermost frame. It's to schedule some delayed processing
//    for later, when the whole current queue is consumed.
// 2. To the tail of the current frame. This delays the processing of that rowop until
//    all the effects from the rowop being processed now are finished.
// 3. To push a new frame, add the rowop there, and immediately start executing it.
//    This works like a function call, making sure that all the effects from that
//    rowop are finished before the current processing resumes.
//
// Since the Units in different threads need to communicate, it's an Mtarget.
class Unit : public Mtarget
{
public:
	// @param name - a human-readable name of this unit, for tracing
	Unit(const string &name);

	// Append a rowop to the end of the outermost queue frame.
	void schedule(Onceref<Rowop> rop);
	// Append the contents of a tray to the end of the outermost queue frame.
	void scheduleTray(const_Onceref<Tray> tray);

	// Append a rowop to the end of the current inner queue frame.
	void fork(Onceref<Rowop> rop);
	// Append the contents of a tray to the end of the current inner queue frame.
	void forkTray(const_Onceref<Tray> tray);

	// Push a new frame and execute the rowop on it, until the frame empties.
	// Then pop that frame, restoring the stack of queues.
	void call(Onceref<Rowop> rop);
	// Push a new frame with the copy of this tray and execute the ops until the frame empties.
	// Then pop that frame, restoring the stack of queues.
	void callTray(const_Onceref<Tray> tray);

	// Enqueue the rowop with the chosen mode. This is mostly for convenience
	// of Perl code but can be used in other places too, performs a switch
	// and calls one of the actula methods.
	// @param em - enqueuing mode, Gadget::EnqMode
	// @param rop - Rowop
	void enqueue(int em, Onceref<Rowop> rop);
	// Enqueue the tray with the chosen mode. This is mostly for convenience
	// of Perl code but can be used in other places too, performs a switch
	// and calls one of the actula methods.
	// @param em - enqueuing mode, Gadget::EnqMode
	// @param tray - tray of rowops
	void enqueueTray(int em, const_Onceref<Tray> tray);

	// Enqueue each record from the tray according to its enqMode.
	// "Delayed" here doesn't mean that the processing will be delayed,
	// it's for use in case if a Gadget collects the rowops instead
	// of processin gthem immediately, and only then (thus already "delayed")
	// enqueues them.
	// No similar call for Rowop, because it can be easily replaced 
	// with enqueue(rop->getEnqMode(), rop).
	void enqueueDelayedTray(const_Onceref<Tray> tray);

	// Extract and execute the next record from the innermost frame.
	void callNext();
	// Execute until the current stack frame drains.
	void drainFrame();

	// Check whether the queue is empty.
	// @return - if no rowops in the whole queue
	bool empty() const;

	// Get the human-readable name
	const string &getName() const
	{
		return name_;
	}

	void setName(const string &name)
	{
		name_ = name;
	}

	// XXX There is an issue with potential circular references, when the labels
	// refer to each other with Autorefs, and the topology includes a loop.
	// Then the labels in the loop will never be freed. A potential solution
	// would be for the loop to keep track of all the labels, and let the
	// user program call a clearing request to all of them (through an added method).

	// Tracing interface.
	// Often it's hard to figure out, how a certain result got produced.
	// This allows the user to trace the whole execution sequence.
	// {

	// the tracer function is called multiple times during the processing of a rowop,
	// with the indication of when it's called:
	enum TracerWhen {
		TW_BEFORE, // before calling the label's execution as such
		TW_BEFORE_DRAIN, // after execution as such, before draining the frame
		TW_BEFORE_CHAINED, // after execution and draining, before calliong the chained labels
		TW_AFTER, // after all the execution is done
		// XXX should there be events on enqueueing?
	};

	// convert the when-code to a string
	static const char *tracerWhenString(int when, const char *def = "???");
	static int stringTracerWhen(const char *when);
	
	// convert the when-code to a more human-readable string (better for debug messages and such)
	static const char *tracerWhenHumanString(int when, const char *def = "???");
	static int humanStringTracerWhen(const char *when);

	// The type of tracer callback functor: inherit from it and redefine your own execute()
	class Tracer : public Mtarget
	{
	public:
		virtual ~Tracer();

		// The callback on some event related to rowop execution happens
		// @param unit - unit from where the tracer is called
		// @param label - label that is being called
		// @param fromLabel - during the chained calls, the parent label, otherwise NULL
		// @param rop - rop operation that is executed
		// @param when - the kind of event
		virtual void execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, TracerWhen when) = 0;
	};

	// For convenience, a concrete tracer class that collects the trace information
	// into an Errors object. It's a very typical usage to track the sequence of execution
	// and get it back as a string (Errors here takes the task of converting to string).
	class StringTracer : public Tracer
	{
	public:
		// @param verbose - if true, record all the events, otherwise only the BEGIN records
		StringTracer(bool verbose = false);

		// Get back the buffer of messages
		// (it can also be used to add messages to the buffer)
		Erref getBuffer() const
		{
			return buffer_;
		}

		// Replace the message buffer with a clean one.
		// The old one gets simply dereferenced, so if you have a reference, you can keep it.
		void clearBuffer();

		// from Tracer
		virtual void execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, TracerWhen when);

	protected:
		Erref buffer_;
		bool verbose_;
	};

	// Another version of string tracer that doesn't print the object addresses, 
	// prints only names.
	class StringNameTracer : public StringTracer
	{
	public:
		// @param verbose - if true, record all the events, otherwise only the BEGIN records
		StringNameTracer(bool verbose = false);

		// from Tracer
		virtual void execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, TracerWhen when);
	};

	// Set the new tracer
	void setTracer(Onceref<Tracer> tracer);

	// Get back the current tracer
	Onceref<Tracer> getTracer() const
	{
		return tracer_;
	}

	// A callback for the Label, to trace its execution
	void trace(const Label *label, const Label *fromLabel, Rowop *rop, TracerWhen when);

	// }
protected:
	// Push a new frame onto the stack, unless the current frame is empty
	// @return - true if the frame was actually pushed
	bool pushFrame();

	// Pop the current frame from stack. It doesn't check whether the frame is empty.
	void popFrame();

protected:
	// the scheduling queue, trays work as stack frames on it
	// (there might be a more efficient way to do it, but for now it's good enough)
	typedef list< Autoref<Tray> > TrayList;
	TrayList queue_;
	Tray *outerFrame_; // the outermost frame
	Tray *innerFrame_; // the current innermost frame (may happen to be the same as outermost)
	Autoref<Tracer> tracer_; // the tracer object
	string name_; // human-readable name for tracing
};

}; // TRICEPS_NS

#endif // __Triceps_Unit_h__
