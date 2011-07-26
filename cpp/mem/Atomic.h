//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The operations to work on atomic integers (using an external implementation
// or with plain mutexes).

#ifndef __Triceps_Atomic_h__
#define __Triceps_Atomic_h__

#include <pw/ptwrap.h>

namespace TRICEPS_NS {

// the baseline implementation when nothing better is available
class AtomicInt
{
public:
	AtomicInt(); // value defaults to 0
	AtomicInt(int val);

	// set the value
	void set(int val)
	{
		mt_mutex_.lock(); // for perversive architectures with software cache coherence
		val_ = val;
		mt_mutex_.unlock();
	}

	// get the value
	int get() const
	{
		return val_;
	}

	// increase the value, return the result
	int inc()
	{
		mt_mutex_.lock();
		int v = ++val_;
		mt_mutex_.unlock();
		return v;
	}

	// derease the value, return the result
	int dec()
	{
		mt_mutex_.lock();
		int v = --val_;
		mt_mutex_.unlock();
		return v;
	}

protected:
	pw::pmutex mt_mutex_;
	int val_;

private:
	void operator=(const AtomicInt &);
	AtomicInt(const AtomicInt &);
};

}; // TRICEPS_NS

#endif // __Triceps_Atomic_h__
