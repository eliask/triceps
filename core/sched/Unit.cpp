//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The basic execution unit.

#include <sched/Unit.h>

namespace BICEPS_NS {

///////////////////////////// Unit //////////////////////////////////

Unit::Unit()
{
	// the outermost frame is always present
	innerFrame_ = outerFrame_ = new Tray;
	queue_.push_front(outerFrame_);
}

void Unit::schedule(Onceref<const Rowop> rop)
{
	outerFrame_->push_back(rop);
}

void Unit::schedule(Onceref<const Tray> tray)
{
	for (Tray::const_iterator it = tray->begin(); it != tray->end(); ++it)
		outerFrame_->push_back(*it);
}


void Unit::fork(Onceref<const Rowop> rop)
{
	innerFrame_->push_back(rop);
}

void Unit::fork(Onceref<const Tray> tray)
{
	for (Tray::const_iterator it = tray->begin(); it != tray->end(); ++it)
		innerFrame_->push_back(*it);
}


void Unit::call(Onceref<const Rowop> rop)
{
	// here a little optimization allows to avoid pushing extra frames
	bool pushed = pushFrame();

	rop->getLabel()->call(this, rop); // also drains the frame

	if (pushed)
		popFrame();
}

void Unit::call(Onceref<const Tray> tray)
{
	bool pushed = pushFrame();

	fork(tray);
	drainFrame();

	if (pushed)
		popFrame();
}


void Unit::callNext()
{
	if (!innerFrame_->empty()) {
		Autoref<const Rowop> rop = innerFrame_->front();
		innerFrame_->pop_front();

		bool pushed = pushFrame();

		rop->getLabel()->call(this, rop); // also drains the frame

		if (pushed)
			popFrame();
	}
}

void Unit::drainFrame()
{
	while (!innerFrame_->empty())
		callNext();
}

bool Unit::pushFrame()
{
	if (!innerFrame_->empty()) {
		innerFrame_ = new Tray;
		queue_.push_front(innerFrame_);
		return true;
	} else
		return false;
}

void Unit::popFrame()
{
	if (innerFrame_ != outerFrame_) { // never pop the outermost frame
		queue_.pop_front();
		innerFrame_ = queue_.front();
	}
}

}; // BICEPS_NS
