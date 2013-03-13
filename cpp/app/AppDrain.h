//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The scoped App drains.

#ifndef __Triceps_AppDrain_h__
#define __Triceps_AppDrain_h__

#include <app/TrieadOwner.h>

namespace TRICEPS_NS {

// The scoped drains. Can be created directly as a scoped
// variable of be kept in a scoped reference.

class AutoDrainShared: public Starget
{
public:
	// @param app - the App to drain
	AutoDrainShared(App *app):
		app_(app)
	{
		app_->drain();
	}
	// @param to - any AppDrain belonging to the App to drain
	AutoDrainShared(TrieadOwner *to):
		app_(to->app())
	{
		app_->drain();
	}

	~AutoDrainShared()
	{
		app_->undrain();
	}

protected:
	Autoref<App> app_;
};

class AutoDrainExclusive: public Starget
{
public:
	// @param to - the AppDrain that is excepted from the drain
	AutoDrainExclusive(TrieadOwner *to):
		to_(to)
	{
		to_->drainExclusive();
	}

	~AutoDrainExclusive()
	{
		to_->undrain();
	}

protected:
	Autoref<TrieadOwner> to_;
};

}; // TRICEPS_NS

#endif // __Triceps_AppDrain_h__
