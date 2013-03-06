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

// an improved version of autoevent
class autoevent2
{
public:
	autoevent2(bool signaled = false) :
		signaled_(signaled), evsleepers_(0)
	{ }

	int wait()
	{
		pw::lockmutex lm(cond_);
		return waitL();
	}
	int waitL()
	{
		++evsleepers_;
		while (!signaled_)
			cond_.wait();
		--evsleepers_;
		signaled_ = false;
		return 0;
	}
	int trywait()
	{
		pw::lockmutex lm(cond_);
		return trywaitL();
	}
	int trywaitL()
	{
		if (!signaled_)
			return ETIMEDOUT;
		signaled_ = false;
		return 0;
	}
	int timedwait(const struct timespec &abstime)
	{
		pw::lockmutex lm(cond_);
		return timedwaitL(abstime);
	}
	int timedwaitL(const struct timespec &abstime);
	int signal()
	{
		pw::lockmutex lm(cond_);
		return signalL();
	}
	int signalL()
	{
		signaled_ = true;
		cond_.signal();
		return 0;
	}
	int reset()
	{
		pw::lockmutex lm(cond_);
		return resetL();
	}
	int resetL()
	{
		signaled_ = false;
		return 0;
	}
	int pulse()
	{
		pw::lockmutex lm(cond_);
		return pulseL();
	}
	int pulseL()
	{
		if (evsleepers_ > 0) {
			signaled_ = true;
			cond_.signal();
		} else {
			signaled_ = false;
		}
		return 0;
	}
	bool read()
	{
		return signaled_;
	}

	// contains both condition variable and a mutex
	pw::pmcond cond_; 
	// semaphore has been signaled
	bool signaled_; 
	// the counter of waiting threads
	int evsleepers_; 
};

}; // pw

}; // TRICEPS_NS

#endif // __Triceps_ptwrap2_hpp__
