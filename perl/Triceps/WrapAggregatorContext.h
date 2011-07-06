//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The "wrapper" that stores the AggregatorContext data.

#include <type/AggregatorType.h>
#include <sched/AggregatorGadget.h>
#include <table/Aggregator.h>

// ###################################################################################

#ifndef __TricepsPerl_WrapAggregatorContext_h__
#define __TricepsPerl_WrapAggregatorContext_h__

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

// This is not really a wrapper, it's really the aggregator context that points to
// a bunch of objects. But since it  follows the convention of Wrap* classes,
// it's named consistently to them.
//
// Currently it refers to the components in the same way as the aggregator handler
// call, by pointers, instead of counted references. This makes it faster but
// potentially unsafe if the context object is abused and preserved outside of the 
// aggregator handler call. It must never be kept past the return of the aggregator
// handler!!!
extern WrapMagic magicWrapAggregatorContext; // defined in AggregatorContext.xs
class WrapAggregatorContext
{
public:
	WrapAggregatorContext(AggregatorGadget *gadget, Index *index,
			IndexType *parentIndexType, GroupHandle *gh, Tray *dest, Tray *copyTray) :
		magic_(magicWrapAggregatorContext),
		gadget_(gadget),
		index_(index),
		parentIndexType_(parentIndexType),
		gh_(gh),
		dest_(dest),
		copyTray_(copyTray)
	{ }

	bool badMagic()
	{
		return magic_ != magicWrapAggregatorContext;
	}

	AggregatorGadget *getGadget() const
	{
		return gadget_;
	}

	Index *getIndex() const
	{
		return index_;
	}

	IndexType *getParentIdxType() const
	{
		return parentIndexType_;
	}

	GroupHandle *getGroupHandle() const
	{
		return gh_;
	}

	Tray *getDest() const
	{
		return dest_;
	}

	Tray *getCopyTray() const
	{
		return copyTray_;
	}

protected:
	WrapMagic magic_;
	AggregatorGadget *gadget_;
	Index *index_;
	IndexType *parentIndexType_;
	GroupHandle *gh_;
	Tray *dest_;
	Tray *copyTray_;
private:
	WrapAggregatorContext();
};

}; // Triceps::TricepsPerl
}; // Triceps

using namespace Triceps::TricepsPerl;

#endif // __TricepsPerl_WrapAggregatorContext_h__
