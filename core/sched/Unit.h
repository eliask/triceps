//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The basic execution unit.

#ifndef __Biceps_Unit_h__
#define __Biceps_Unit_h__

#include <common/Common.h>
#include <sched/Tray.h>
#include <sched/Label.h>
#include <list>

namespace BICEPS_NS {

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
class Unit : public Starget
{
public:
	Unit();

	// Append a rowop to the end of the outermost queue frame.
	void schedule(Onceref<const Rowop> rop);
	// Append the contents of a tray to the end of the outermost queue frame.
	void schedule(Onceref<const Tray> tray);

	// Append a rowop to the end of the current inner queue frame.
	void fork(Onceref<const Rowop> rop);
	// Append the contents of a tray to the end of the current inner queue frame.
	void fork(Onceref<const Tray> tray);

	// Push a new frame and execute the rowop on it, until the frame empties.
	// Then pop that frame, restoring the stack of queues.
	void call(Onceref<const Rowop> rop);
	// Push a new frame with the copy of this tray and execute the ops until the frame empties.
	// Then pop that frame, restoring the stack of queues.
	void call(Onceref<const Tray> tray);

	// Extract and execute the next record from the innermost frame.
	void callNext();
	// Execute until the current stack frame drains.
	void drainFrame();

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
};

}; // BICEPS_NS

#endif // __Biceps_Unit_h__
