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

class FnReturnGuts: public FnReturn
{
public:
	static Xtray *getXtray(FnReturn *fret)
	{
		const FnReturnGuts *frg = (FnReturnGuts *)fret;
		return frg->xtray_;
	}

	static bool isXtrayEmpty(FnReturn *fret)
	{
		const FnReturnGuts *frg = (FnReturnGuts *)fret;
		return frg->FnReturn::isXtrayEmpty();
	}

	static void swapXtray(FnReturn *fret, Autoref<Xtray> &other)
	{
		FnReturnGuts *frg = (FnReturnGuts *)fret;
		frg->FnReturn::swapXtray(other);
	}
};

class FacetGuts: public Facet
{
public:
	static ReaderQueue *readerQueue(Facet *fa)
	{
		FacetGuts *fg = (FacetGuts *)fa;
		return fg->rd_;
	}

	static NexusWriter *nexusWriter(Facet *fa)
	{
		FacetGuts *fg = (FacetGuts *)fa;
		return fg->wr_;
	}
};

class NexusGuts: public Nexus
{
public:
	static ReaderVec *readers(Nexus *nx)
	{
		NexusGuts *ng = (NexusGuts *)nx;
		return ng->readers_;
	}

	static WriterVec *writers(Nexus *nx)
	{
		NexusGuts *ng = (NexusGuts *)nx;
		return &ng->writers_;
	}

	static void deleteReader(Nexus *nx, ReaderQueue *rq)
	{
		NexusGuts *ng = (NexusGuts *)nx;
		ng->Nexus::deleteReader(rq);
	}

	static void deleteWriter(Nexus *nx, NexusWriter *wr)
	{
		NexusGuts *ng = (NexusGuts *)nx;
		ng->Nexus::deleteWriter(wr);
	}
};

class NexusWriterGuts: public NexusWriter
{
public:
	static ReaderVec *readers(NexusWriter *nx)
	{
		NexusWriterGuts *ng = (NexusWriterGuts *)nx;
		return ng->readers_;
	}

	static ReaderVec *readersNew(NexusWriter *nx)
	{
		NexusWriterGuts *ng = (NexusWriterGuts *)nx;
		return ng->readersNew_;
	}

};

class ReaderQueueGuts: public ReaderQueue
{
public:
	static int &gen(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->gen_;
	}

	static bool &isDead(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->dead_;
	}

	static bool &wrhole(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->wrhole_;
	}

	static bool &wrReady(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->wrReady_;
	}

	static Xtray::QueId &prevId(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->prevId_;
	}

	static Xtray::QueId &lastId(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->lastId_;
	}

	static Xdeque &writeq(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->ReaderQueue::writeq();
	}

	static Xdeque &readq(ReaderQueue *rq)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		return rqg->ReaderQueue::readq();
	}

	static void setLastId(ReaderQueue *rq, Xtray::QueId id)
	{
		ReaderQueueGuts *rqg = (ReaderQueueGuts *)rq;
		rqg->ReaderQueue::setLastIdL(id);
	}

};

// really need to look in the guts for the state,
// can't just do it by the honest waiting because it changes the state
class autoeventGuts: public pw::autoevent
{
public:
	static bool isSignaled(pw::autoevent &ev)
	{
		autoeventGuts *evg = (autoeventGuts *)&ev;
		return evg->signaled_;
	}

	static int sleepers(pw::autoevent &ev)
	{
		autoeventGuts *evg = (autoeventGuts *)&ev;
		return evg->evsleepers_;
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

uint8_t v_uint8[10] = "123456789";
int32_t v_int32 = 1234;
int64_t v_int64 = 0xdeadbeefc00c;
double v_float64 = 9.99e99;
char v_string[] = "hello world";

void mkfdata(FdataVec &fd)
{
	fd.resize(4);
	fd[0].setPtr(true, &v_uint8, sizeof(v_uint8));
	fd[1].setPtr(true, &v_int32, sizeof(v_int32));
	fd[2].setPtr(true, &v_int64, sizeof(v_int64));
	fd[3].setPtr(true, &v_float64, sizeof(v_float64));
	// test the constructor
	fd.push_back(Fdata(true, &v_string, sizeof(v_string)));
}

