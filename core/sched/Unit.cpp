//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The basic execution unit.

#include <sched/Unit.h>

namespace BICEPS_NS {

///////////////////////////// Unit::Tracer //////////////////////////////////

Unit::Tracer::~Tracer()
{ }

///////////////////////////// Unit::StringTracer //////////////////////////////////

Unit::StringTracer::StringTracer() :
	buffer_(new Errors)
{ }

void Unit::StringTracer::clearBuffer()
{
	buffer_ = new Errors;
}

void Unit::StringTracer::execute(Unit *unit, const Label *label, const Label *fromLabel, const Rowop *rop, TracerWhen when)
{
	buffer_->appendMsg(false, strprintf("unit %p '%s' %s label %p '%s' (chain %p) op %p %s", 
		unit, unit->getName().c_str(), tracerWhenString(when),
		label, label->getName().c_str(), fromLabel, 
		rop, Rowop::opcodeString(rop->getOpcode()) ));

	// XXX hexdump the row too?
}

///////////////////////////// Unit::StringNameTracer //////////////////////////////////

void Unit::StringNameTracer::execute(Unit *unit, const Label *label, const Label *fromLabel, const Rowop *rop, TracerWhen when)
{
	string res = strprintf("unit '%s' %s label '%s' ", 
		unit->getName().c_str(), tracerWhenString(when), label->getName().c_str());

	if (fromLabel != NULL) {
		res.append("(chain '");
		res.append(fromLabel->getName());
		res.append(") ");
	};
	res.append("op ");
	res.append(Rowop::opcodeString(rop->getOpcode()));

	buffer_->appendMsg(false, res);
	
	// XXX hexdump the row too?
}

///////////////////////////// Unit //////////////////////////////////

Unit::Unit(const string &name) :
	name_(name)
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

void Unit::trace(const Label *label, const Label *fromLabel, const Rowop *rop, TracerWhen when)
{
	if (!tracer_.isNull()) {
		tracer_->execute(this, label, fromLabel, rop, when);
	}
}

}; // BICEPS_NS
