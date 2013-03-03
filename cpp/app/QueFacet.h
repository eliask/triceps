//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Various bits and pieces for the facet queues.

#ifndef __Triceps_QueFacet_h__
#define __Triceps_QueFacet_h__

#include <deque>
#include <common/Common.h>
#include <pw/ptwrap.h>
#include <mem/Atomic.h>
#include <app/Xtray.h>

// XXX work in progress

namespace TRICEPS_NS {

// These small classes logically belong as fragments to the bigger objects
// but had to be separated to keep the reference counting from creating
// the cycles.

// Notification from the Nexuses to the Triead that there is something
// to read. Done as a separate object because the Nexuses will need
// to refrence it, and they can not reference the Tried directly
// because that would cause a reference loop.
// This event covers all the facets connected to the thread.
class QueEvent: public Mtarget
{
public:
	pw::autoevent ev_;
};

// The queue of one reader facet.
class ReaderQueue: public Mtarget
{
	friend class Nexus;
public:
	typedef deque<Autoref<Xtray> > Xdeque;

	// @param qev - the thread's notification event
	// @param qidx - the queue index to use in the notification
	// @param limit - high watermark limit for the queue
	ReaderQueue(QueEvent *qev, int qidx, Xtray::QueId limit);

	// Write an Xtray to the first reader in the vector.
	// This generates the sequential id for the Xtray.
	// May sleep if the write queue is full.
	//
	// @param gen - generation of the vector used by the writer
	// @param xt - Xtray being written
	// @param trayId - place to return the generated id of the tray
	// @return - true if the generations matched and the write went through
	//        and generated the id; false if the generations were mismatched
	//        or if this reader is marked as dead, and nothing was done
	bool writeFirst(int gen, Xtray *xt, Xtray::QueId &trayId);

	// Write an Xtray with a specific sequence to a reader that is
	// not first in the vector. Does nothing if the queue is dead.
	// May sleep if the write queue is full.
	//
	// @param xt - Xtray being written
	// @param trayId - the sequential id of the tray
	void write(Xtray *xt, Xtray::QueId trayId);

	// Refill the read side of the queue from the write side.
	// @return - whether the data became available in the reader queue
	bool refill();

	// Pop a value from the front of the read queue. 
	// Set it to NULL before popping, to make sure that a reference
	// won't be stuck in the queue for a long time.
	void popread()
	{
		Xdeque &q = readq();
		q.front() = NULL;
		q.pop_front();
	}

	// Get the value from the front of the read queue.
	// The value is returned as a pointer, to reduce the number of
	// reference changes. Like STL front(), the value is not popped,
	// so it's safe to use the pointer until popread() is called.
	//
	// @return - the next item from the front of the read queue, or
	//           NULL if none is available any more (the write queue
	//           may still have data)
	Xtray *frontread() const
	{
		const Xdeque &q = q_[rq_]; // readq(), only preserve the constness
		if (q.empty())
			return NULL;
		return q.front().get();
	}

protected:

	Xdeque &writeq()
	{
		return q_[rq_ ^ 1];
	}
	Xdeque &readq()
	{
		return q_[rq_];
	}
	pw::pmutex &mutex()
	{
		return condfull_;
	}

	// Update the generation of the reader vector.
	// The caller should lock the mutex_ or otherwise have
	// this reader not accessible to writers yet.
	void setGenL(int gen)
	{
		gen_ = gen;
	}

	// Update the lastId_, so that it's consistent across all the readers.
	// Done when a reader is deleted, to allow the use of any of them as the
	// new first reader.
	// Stretches the queue as needed.
	// The caller should lock the mutex_ or otherwise have
	// this reader not accessible to writers yet.
	void setLastIdL(Xtray::QueId id);

	// Insert an Xtray into the write queue at the specified index
	// relative to the start of the queue.
	// Extends the queue as needed. Never blocks.
	// @param xt - Xtray to insert
	// @param idx - index to insert at
	void insertQueL(Xtray *xt, Xtray::QueId idx);

	// Mark this reader as dead and disconnected from the nexus.
	// This clears the queue.
	// All the future writes to it will be no-ops.
	void markDeadL();

	// part that is set once and never changed
	
	Autoref<QueEvent> qev_; // where to signal when have data
	int qidx_; // index of this facet's indication in QueEvent::ready_

	// XXX set very high for the "never block" reverse nexuses
	Xtray::QueId sizeLimit_; // the high water mark for writing

	// part that is either protected by the mutex or used only by the
	// facet-owning thread
	// XXX should bother to separate better the part used by the facet-owning thread?

	Xdeque q_[2]; // the queues of trays; they alternate with double buffering;
		// the one currently used for reading can be accessed without a lock
	int rq_; // index of the queue that is currently used for reading
		// changed only by the reader thread, with mutex locked,
		// so that thread 

	// the Xtray ids may roll over
	Xtray::QueId prevId_; // id of the last Xtray preceding the start of the queue
	Xtray::QueId lastId_; // id of the last Xtray at the end of the queue
		// (if prevId_ and lastId_ are the same, the queue is empty)

	int gen_; // the generation of the nexus's reader vector

	bool wrhole_; // the write queue had a hole in it, so it can't be simply swapped with read queue
	bool dead_; // this queue has been disconnected from the nexus

	bool wrReady_; // there is new data in the writer queue
	pw::pmcond condfull_; // wait when the queue is full, also contains the mutex


private:
	ReaderQueue();
	ReaderQueue(const ReaderQueue &);
	void operator=(const ReaderQueue &);
};

// Collection of the reader facets in a Nexus. The writers will
// be sending data to all of them. Done as a separate object, so that
// all the writers can refer to it.
//
// As the readers are added and deleted from a nexus, the new ReaderVec
// objects are created, each with an increased generation number.
// The addition and deletion are infrequent operations and can afford
// to be expensive.
//
// Like other shared objects, it's all-writes-before-sharing.
class ReaderVec: public Mtarget
{
	friend class Nexus;
public:
	typedef vector<Autoref<ReaderQueue> > Vec;

	// @param g - the generation
	ReaderVec(int g):
		gen_(g)
	{ }
		
	// read the vector
	const Vec &v() const
	{
		return v_;
	}

	// read the generation
	int gen() const
	{
		return gen_;
	}

protected:
	Vec v_; // the Nexus will add directly to it on construction
	int gen_; // the generation of the vector

private:
	ReaderVec();
	ReaderVec(const ReaderVec &);
	void operator=(const ReaderVec &);
};

class NexusWriter: public Mtarget
{
public:
	NexusWriter()
	{ }

	// Update the new reader vector (readersNew_).
	// @param rv - the new vector (the caller must hold a reference to it
	//        through the call). The writer will discover it on the next
	//        attempt to write.
	void setReaderVec(ReaderVec *rv);

	// Write the Xtray.
	// Called only from the thread that owns this facet.
	//
	// @param xt - the data (the caller must hold a reference to it
	//        through the call, the caller must not change the Xtray contents
	//        afterwards).
	void write(Xtray *xt);

protected:
	Autoref<ReaderVec> readers_; // the current active reader vector

	pw::pmutex mutexNew_; // protects the readersNew_
	Autoref<ReaderVec> readersNew_; // the new reader vector

private:
	NexusWriter(const NexusWriter &);
	void operator=(const NexusWriter &);
};

}; // TRICEPS_NS

#endif // __Triceps_QueFacet_h__
