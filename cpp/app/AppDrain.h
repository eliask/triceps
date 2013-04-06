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
	// @param wait - flag: right away wait for the drain to complete
	AutoDrainShared(App *app, bool wait = true):
		app_(app)
	{
		if (wait)
			app_->drain();
		else
			app_->requestDrain();
	}
	// @param to - any AppDrain belonging to the App to drain
	// @param wait - flag: right away wait for the drain to complete
	AutoDrainShared(TrieadOwner *to, bool wait = true):
		app_(to->app())
	{
		if (wait)
			app_->drain();
		else
			app_->requestDrain();
	}

	~AutoDrainShared()
	{
		app_->undrain();
	}

	// Wait for the drain to complete. May be used repeatedly inside
	// the scope, since it's possible for the drain owner to insert
	// more data and wait for it to be drained again.
	void wait()
	{
		app_->waitDrain();
	}

protected:
	Autoref<App> app_;

private:
	AutoDrainShared();
	AutoDrainShared(const AutoDrainShared&);
	void operator=(const AutoDrainShared &);
};

class AutoDrainExclusive: public Starget
{
public:
	// @param to - the AppDrain that is excepted from the drain
	// @param wait - flag: right away wait for the drain to complete
	AutoDrainExclusive(TrieadOwner *to, bool wait = true):
		to_(to)
	{
		if (wait)
			to_->drainExclusive();
		else
			to_->requestDrainExclusive();
	}

	~AutoDrainExclusive()
	{
		to_->undrain();
	}

	// Wait for the drain to complete. May be used repeatedly inside
	// the scope, since it's possible for the drain owner to insert
	// more data and wait for it to be drained again.
	void wait()
	{
		to_->waitDrain();
	}

protected:
	Autoref<TrieadOwner> to_;

private:
	AutoDrainExclusive();
	AutoDrainExclusive(const AutoDrainExclusive&);
	void operator=(const AutoDrainExclusive &);
};

}; // TRICEPS_NS

#endif // __Triceps_AppDrain_h__
