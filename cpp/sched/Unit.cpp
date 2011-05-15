//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The basic execution unit.

#include <sched/Unit.h>
#include <sched/Gadget.h>

namespace TRICEPS_NS {

///////////////////////////// Unit::Tracer //////////////////////////////////

Unit::Tracer::~Tracer()
{ }

///////////////////////////// Unit::StringTracer //////////////////////////////////

Unit::StringTracer::StringTracer(bool verbose) :
	buffer_(new Errors),
	verbose_(verbose)
{ }

void Unit::StringTracer::clearBuffer()
{
	buffer_ = new Errors;
}

void Unit::StringTracer::execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, TracerWhen when)
{
	if (!verbose_ && when != TW_BEFORE)
		return;

	string res = strprintf("unit %p '%s' %s label %p '%s' ",
		unit, unit->getName().c_str(), tracerWhenString(when),
		label, label->getName().c_str());

	if (fromLabel != NULL) {
		res.append(strprintf("(chain %p '%s') ", fromLabel, fromLabel->getName().c_str()));
	};
	res.append(strprintf("op %p %s", rop, Rowop::opcodeString(rop->getOpcode()) ));

	buffer_->appendMsg(false, res);
	// XXX print the row too?
}

///////////////////////////// Unit::StringNameTracer //////////////////////////////////

Unit::StringNameTracer::StringNameTracer(bool verbose) :
	StringTracer(verbose)
{ }

void Unit::StringNameTracer::execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, TracerWhen when)
{
	if (!verbose_ && when != TW_BEFORE)
		return;

	string res = strprintf("unit '%s' %s label '%s' ", 
		unit->getName().c_str(), tracerWhenString(when), label->getName().c_str());

	if (fromLabel != NULL) {
		res.append("(chain '");
		res.append(fromLabel->getName());
		res.append("') ");
	};
	res.append("op ");
	res.append(Rowop::opcodeString(rop->getOpcode()));

	buffer_->appendMsg(false, res);
	
	// XXX print the row too?
}

///////////////////////////// Unit //////////////////////////////////

Unit::Unit(const string &name) :
	name_(name)
{
	// the outermost frame is always present
	innerFrame_ = outerFrame_ = new Tray;
	queue_.push_front(outerFrame_);
}

void Unit::schedule(Onceref<Rowop> rop)
{
	outerFrame_->push_back(rop);
}

void Unit::scheduleTray(const_Onceref<Tray> tray)
{
	for (Tray::const_iterator it = tray->begin(); it != tray->end(); ++it)
		outerFrame_->push_back(*it);
}


void Unit::fork(Onceref<Rowop> rop)
{
	innerFrame_->push_back(rop);
}

void Unit::forkTray(const_Onceref<Tray> tray)
{
	for (Tray::const_iterator it = tray->begin(); it != tray->end(); ++it)
		innerFrame_->push_back(*it);
}


void Unit::call(Onceref<Rowop> rop)
{
	// here a little optimization allows to avoid pushing extra frames
	bool pushed = pushFrame();

	rop->getLabel()->call(this, rop); // also drains the frame

	if (pushed)
		popFrame();
}

void Unit::callTray(const_Onceref<Tray> tray)
{
	bool pushed = pushFrame();

	forkTray(tray);
	drainFrame();

	if (pushed)
		popFrame();
}

void Unit::enqueue(int em, Onceref<Rowop> rop)
{
	switch(em) {
	case Gadget::EM_SCHEDULE:
		schedule(rop);
		break;
	case Gadget::EM_FORK:
		fork(rop);
		break;
	case Gadget::EM_CALL:
		call(rop);
		break;
	case Gadget::EM_IGNORE:
		break;
	default:
		fprintf(stderr, "Triceps API violation: Invalid enqueueing mode %d\n", em);
		abort();
		break;
	}
}

void Unit::enqueueTray(int em, const_Onceref<Tray> tray)
{
	switch(em) {
	case Gadget::EM_SCHEDULE:
		scheduleTray(tray);
		break;
	case Gadget::EM_FORK:
		forkTray(tray);
		break;
	case Gadget::EM_CALL:
		callTray(tray);
		break;
	case Gadget::EM_IGNORE:
		break;
	default:
		fprintf(stderr, "Triceps API violation: Invalid enqueueing mode %d\n", em);
		abort();
		break;
	}
}

void Unit::enqueueDelayedTray(const_Onceref<Tray> tray)
{
	for (Tray::const_iterator it = tray->begin(); it != tray->end(); ++it) {
		Rowop *rop = *it;
		enqueue(rop->getEnqMode(), rop);
	}
}

void Unit::callNext()
{
	if (!innerFrame_->empty()) {
		Autoref<Rowop> rop = innerFrame_->front();
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

bool Unit::empty() const
{
	return innerFrame_ == outerFrame_ && innerFrame_->empty();
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

const char *Unit::tracerWhenString(TracerWhen when)
{
	switch(when) {
	case TW_BEFORE:
		return "before";
	case TW_BEFORE_DRAIN:
		return "drain";
	case TW_BEFORE_CHAINED:
		return "before-chained";
	case TW_AFTER:
		return "after";
	default:
		return "???unknown???";
	}
}

void Unit::setTracer(Onceref<Tracer> tracer)
{
	tracer_ = tracer;
}

void Unit::trace(const Label *label, const Label *fromLabel, Rowop *rop, TracerWhen when)
{
	if (!tracer_.isNull()) {
		tracer_->execute(this, label, fromLabel, rop, when);
	}
}

}; // TRICEPS_NS
