//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The multi-threaded target for a reference with counting.

#ifndef __Biceps_Mtarget_h__
#define __Biceps_Mtarget_h__

#include <mem/Autoref.h> // just for convenience
#include <pw/ptwrap.h>

namespace BICEPS_NS {

// The multithreaded references could certainly benefit from
// atomic operations on the counter. But for now let's just do it
// in a portable way.
class Mtarget
{
public:
	Mtarget() :
		count_(0)
	{ }

	// The copy constructor and assignment must NOT copy the count!
	// Each object has its own count that can't be messed with.
	// Now, directly assigning a multiple-referenced object is
	// generally not a good idea, but it's not this class's problem.
	Mtarget(const Mtarget &t) :
		count_(0)
	{ }
	void operator=(const Mtarget &t)
	{ }

	// the operations on the count
	void incref() const
	{
		mt_mutex_.lock();
		++count_;
		mt_mutex_.unlock();
	}

	int decref() const
	{
		mt_mutex_.lock();
		int c = --count_;
		mt_mutex_.unlock();
		return c;
	}

	// this one is mostly for unit tests
	int getref() const
	{
		return count_;
	}

protected:
	mutable pw::pmutex mt_mutex_;
private: // the subclasses really shouldn't mess with it
	mutable int count_;
};

}; // BICEPS_NS

#endif // __Biceps_Mtarget_h__
