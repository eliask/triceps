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
#include <sched/FrameMark.h>
#include <list>
#include <map>

namespace TRICEPS_NS {

class Unit;

// One frame of the Unit's scheduling queue.
class UnitFrame : public Tray
{
	friend class Unit;
public:
	// clears the marks as well
	~UnitFrame();

	// Mark this frame
	// @param - Unit identity, to pass to the mark
	// @param mk - mark added to this frame (if it happens to point to another frame,
	//    it will be removed from there first).
	void mark(Unit *unit, Onceref<FrameMark> mk);

	// Check whether this frame has any marks on it.
	bool isMarked() const
	{
		return !markList_.isNull();
	}

	// Clear the marks from frame when it's moved from queue
	// into the free pool
	void clear();

protected:
	Autoref <FrameMark> markList_; // head of the single-linked list of marks at this frame

	// A mark that is being reassigned points to this frame.
	// Free it up for reassignment by dropping from this frame's list.
	void dropFromList(FrameMark *what);
};

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
	~Unit();

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

	// Set the start-of-loop mark to the parent frame.
	// The frame one higher than current is used because the current
	// executing label is the first label of the loop, and when it
	// started execution, it had a new frame created. When a rowop will
	// be enqueued at the mark and eventually executed, it will also
	// have a new frame created for it. For that frame to be at the
	// same level as the current frame, the label must be one level up.
	// If the unit is at the outermost frame (which could happen only
	// if someone calls setMark() outside of the scheduled execution),
	// the mark will be cleared. This will cause the data queued to
	// that mark to go to the outermost frame.
	// @param mark - mark to set
	void setMark(Onceref<FrameMark> mark);
	// Append a rowop to the end of the queue frame pointed by mark.
	// (The frame gets marked at the start of the loop).
	// If the mark points to no frame, append to the outermost queue frame:
	// the logic here is that if a record in the loop gets delayed by
	// time wait, when it continues, it should be scheduled there.
	void loopAt(FrameMark *mark, Onceref<Rowop> rop);
	// Append the contents of a tray to the end of the queue frame pointed by mark.
	// If the mark points to no frame, append to the outermost queue frame.
	void loopTrayAt(FrameMark *mark, const_Onceref<Tray> tray);

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

	// There is an issue with potential circular references, when the labels
	// refer to each other with Autorefs, and the topology includes a loop.
	// Then the labels in the loop will never be freed. A solution used here
	// is for the unit to keep track of all the labels in it, and let the
	// user program send a clearing request to all of them.
	// The Unit and all its labels are normally constructed and used in a
	// single thread (except for the inter-unit communication). So these calls
	// must be used only from this thread and don't need synchronization.
	// {
	
	// Clear all the labels, then drop the references from Unit to them.
	// Normally should be called only when the thread is about to exit!
	void clearLabels();

	// Remember the label. Called from the label constructor.
	void rememberLabel(Label *lab);

	// Forget one label. May be useful in case if the label needs to
	// be deleted early, or some such. This does not clear the label!
	void  forgetLabel(Label *lab);

	// }

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
	// Push a new frame onto the stack.
	void pushFrame();

	// Pop the current frame from stack.
	void popFrame();

protected:
	// the scheduling queue, trays work as stack frames on it
	// (there might be a more efficient way to do it, but for now it's good enough)
	typedef list< Autoref<UnitFrame> > FrameList;
	FrameList queue_;
	FrameList freePool_; // when frames are popped from queue, they're cached here
	UnitFrame *outerFrame_; // the outermost frame
	UnitFrame *innerFrame_; // the current innermost frame (may happen to be the same as outermost)
	Autoref<Tracer> tracer_; // the tracer object
	string name_; // human-readable name for tracing
	// Keeping track of labels
	typedef map<Label *, Autoref<Label> > LabelMap;
	LabelMap labelMap_;

private:
	Unit(const Unit &);
	void operator=(const Unit &);
};

// The idea here is to have an object that definitely would not be involved in
// circular references, even if the Unit is. So when the trigger object 
// goes out of scope, it can trigger the clearLabels()
// call in the Unit. Of course, if you use it, it's your responsibility to not
// involve it in the circular references!
// The UnitClearingTrigger object must be owned by the same thread as owns Unit.
class UnitClearingTrigger : public Mtarget
{
public:
	UnitClearingTrigger(Unit *unit);
	~UnitClearingTrigger();

protected:
	Autoref<Unit> unit_; // makes sure that the unit doesn't disappear
};

}; // TRICEPS_NS

#endif // __Triceps_Unit_h__
