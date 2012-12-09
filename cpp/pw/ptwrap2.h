// This file is the extension of Pthreads Wrapper library.
// See the accompanying COPYRIGHT file for the copyright notice and license.
//
// These are the thread communication functions that weren't in the
// original ptwrap library, added for Triceps.

#ifndef __Triceps_ptwrap2_hpp__
#define __Triceps_ptwrap2_hpp__

#include <pw/ptwrap.h>

namespace TRICEPS_NS {

namespace pw // POSIX wrapped
{

// An event that always starts unsignaled, gets signaled only
// once and stays this way forever. Convenient for initializations.
class oncevent : public basicevent
{
public:
	oncevent() :
		basicevent(false)
	{ }

	// a quick check, whether it has been signaled
	// @return - true if signaled
	bool check()
	{
		return signaled_;
	}

	// A more efficient version of wait, doing the
	// quick check first.
	int wait()
	{
		return signaled_? 0 : basicevent::wait();
	}
	int trywait()
	{
		// If not signaled, better try again with a proper lock,
		// in case if thungs haven't propagated through the SMP yet
		// (not a problem for x86, but just in case).
		return signaled_? 0 : basicevent::trywait();
	}
	int timedwait(const struct timespec &abstime)
	{
		return signaled_? 0 : basicevent::timedwait(abstime);
	}

private:
	// cover the methods that should not be used
	int reset();
	int pulse();
};

}; // pw

}; // TRICEPS_NS

#endif // __Triceps_ptwrap2_hpp__
