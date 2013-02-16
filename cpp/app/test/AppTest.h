//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Helpers for the testing of the app stuff.

#include <app/App.h>
#include <app/TrieadOwner.h>
#include <app/BasicPthread.h>

// Access to the protected internals of App.
class AppGuts : public App
{
public:
	typedef App::NxTr NxTr;
	typedef App::Graph Graph;

	static bool gutsIsReady(App *a)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		return ag->isReady();
	}
	static void gutsWaitReady(App *a)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		ag->waitReady();
	}
	// Busy-wait until the number of sleepers waiting for a
	// thread reaches the count.
	// @param tname - thread name for sleepers
	// @param n - the expected count of sleepers
	static void gutsWaitTrieadSleepers(App *a, const string &tname, int n)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		int nsl;
		do {
			sched_yield();
			pw::lockmutex lm(ag->mutex_);
			TrieadUpdMap::iterator it = ag->threads_.find(tname);
			assert(it != ag->threads_.end());
			nsl = it->second->_countSleepersL();
		} while(nsl != n);
	}
	// Busy-wait until the thread is marked as dead.
	// @param tname - thread name
	static void gutsWaitTrieadDead(App *a, const string &tname)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		while (true) {
			sched_yield();
			pw::lockmutex lm(ag->mutex_);
			TrieadUpdMap::iterator it = ag->threads_.find(tname);
			assert(it != ag->threads_.end());
			if (it->second->t_->isDead())
				return;
		}
	}
	// Busy-wait until the thread is marked as ready.
	// @param tname - thread name
	static void gutsWaitTrieadReady(App *a, const string &tname)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		while (true) {
			sched_yield();
			pw::lockmutex lm(ag->mutex_);
			TrieadUpdMap::iterator it = ag->threads_.find(tname);
			assert(it != ag->threads_.end());
			if (it->second->t_->isReady())
				return;
		}
	}
	// Busy-wait until the thread is marked as constructed.
	// @param tname - thread name
	static void gutsWaitTrieadConstructed(App *a, const string &tname)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		while (true) {
			sched_yield();
			pw::lockmutex lm(ag->mutex_);
			TrieadUpdMap::iterator it = ag->threads_.find(tname);
			assert(it != ag->threads_.end());
			if (it->second->t_->isConstructed())
				return;
		}
	}

	// Get the joiner for a thread.
	static TrieadJoin *gutsJoin(App *a, const string &tname)
	{
		AppGuts *ag = ((AppGuts *)a); // shut up the compiler
		pw::lockmutex lm(ag->mutex_);
		TrieadUpdMap::iterator it = ag->threads_.find(tname);
		assert(it != ag->threads_.end());
		return it->second->j_;
	}

	void checkLoopsL(const string &tname)
	{
		App::checkLoopsL(tname);
	}
	void reduceCheckGraphL(Graph &g, const char *direction) const
	{
		App::reduceCheckGraphL(g, direction);
	}
	void checkGraphL(Graph &g, const char *direction) const
	{
		App::checkGraphL(g, direction);
	}
	static void reduceGraphL(Graph &g)
	{
		App::reduceGraphL(g);
	}
};

class TrieadOwnerGuts: public TrieadOwner
{
public:
	class NexusMakerGuts: public TrieadOwner::NexusMaker
	{
		friend class TrieadOwnerGuts;
	public:
		static FnReturn *getFret(TrieadOwner::NexusMaker &nm)
		{
			NexusMakerGuts *nmg = (NexusMakerGuts *)&nm;
			return nmg->fret_;
		}
		static Facet *getFacet(TrieadOwner::NexusMaker &nm)
		{
			NexusMakerGuts *nmg = (NexusMakerGuts *)&nm;
			return nmg->facet_;
		}
	};

	static FnReturn *nexusMakerFnReturn(TrieadOwner *to)
	{
		TrieadOwnerGuts *tog = (TrieadOwnerGuts *)to;
		return NexusMakerGuts::getFret(tog->nexusMaker_);
	}
	static Facet *nexusMakerFacet(TrieadOwner *to)
	{
		TrieadOwnerGuts *tog = (TrieadOwnerGuts *)to;
		return NexusMakerGuts::getFacet(tog->nexusMaker_);
	}
};

// make the exceptions catchable
void make_catchable()
{
	Exception::abort_ = false; // make them catchable
	Exception::enableBacktrace_ = false; // make the error messages predictable
}

// restore the exceptions back to the uncatchable state
void restore_uncatchable()
{
	Exception::abort_ = true;
	Exception::enableBacktrace_ = true;
}

// Make fields of all simple types
void mkfields(RowType::FieldVec &fields)
{
	fields.clear();
	fields.push_back(RowType::Field("a", Type::r_uint8, 10));
	fields.push_back(RowType::Field("b", Type::r_int32,0));
	fields.push_back(RowType::Field("c", Type::r_int64));
	fields.push_back(RowType::Field("d", Type::r_float64));
	fields.push_back(RowType::Field("e", Type::r_string));
}

