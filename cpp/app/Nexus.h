//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Nexus is a communication point between the threads, a set of labels
// for passing data downstream and upstream.

#ifndef __Triceps_Nexus_h__
#define __Triceps_Nexus_h__

#include <common/Common.h>
#include <mem/Mtarget.h>

namespace TRICEPS_NS {

class Facet;
class Triead;

// Nexus is the machinery that keeps a queue of rowops (their inter-thread
// representations) for passing between the threads. The queue is common
// between all the labels and provides a common order for them. More exactly,
// there might be up to two queues: one "downstream" and one "upstream".
// But the initial goal is to have one per nexus.
//
// The Nexuses could live right on the level under App but in case of the
// deadlocks this would make tracing the cause difficult (i.e. thread A
// waits for a nexus to be defined by thread B, while thread B waits for
// a nexus to be defined by thread A). So each Nexus is associated with and 
// nested under a certain Triead.
class Nexus : public Mtarget
{
	friend class App;
public:
	// The nexus creation consists of the following steps:
	// * create the object;
	// * fill it with the contents;
	// * export it in the thread, thus initializing it and making it
	//   visible throughout the app.
	
	// @param parent - thread that created and owns this nexus.
	// @param name - name of the nexus, must be unique within the thread.
	Nexus(Triead *parent, const string &name);

	// Get the name
	const string &getName() const
	{
		return name_;
	}

	// Check whether the nexus is initializaed and attached.
	bool isInitialized()
	{
		return parent_ != NULL;
	}

protected:
	string name_;
	Triead *parent_; // will be NULL until connected to the Triead

private:
	Nexus();
	Nexus(const Nexus &);
	void operator=(const Nexus &);
};

}; // TRICEPS_NS

#endif // __Triceps_Nexus_h__
