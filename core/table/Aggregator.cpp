//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class for aggregators.

#include <common/Common.h>
#include <table/Aggregator.h>
#include <sched/AggregatorGadget.h>

namespace BICEPS_NS {

Aggregator::~Aggregator()
{ }

const char *Aggregator::aggOpString(AggOp code)
{
	switch(code) {
	case AO_BEFORE_MOD:
		return "BEFORE_MOD";
	case AO_AFTER_DELETE:
		return "AFTER_DELETE";
	case AO_AFTER_INSERT:
		return "AFTER_INSERT";
	case AO_COLLAPSE:
		return "COLLAPSE";
	default:
		return "???";
	}
}

}; // BICEPS_NS

