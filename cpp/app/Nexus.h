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

#include <map>
#include <common/Common.h>
#include <mem/Mtarget.h>
#include <type/RowSetType.h>
#include <type/TableType.h>

namespace TRICEPS_NS {

class Facet;
class Triead;

// Nexus is the machinery that keeps a queue of rowops (their inter-thread
// representations) for passing between the threads. The queue is common
// between all the labels and provides a common order for them. More exactly,
// there might be up to two queues: one "downstream" and one "upstream".
// But the initial goal is to have one per nexus.
//
// Besides the queues, a nexus is used to export the assorted row types
// and table types. They live in their separate sub-namespaces.
//
// The Nexuses could live right on the level under App but in case of the
// deadlocks this would make tracing the cause difficult (i.e. thread A
// waits for a nexus to be defined by thread B, while thread B waits for
// a nexus to be defined by thread A). So each Nexus is associated with and 
// nested under a certain Triead.
class Nexus : public Mtarget
{
	friend class App;
	friend class Triead;
	friend class TrieadOwner;
public:
	typedef map<string, Autoref<RowType> > RowTypeMap;
	typedef map<string, Autoref<TableType> > TableTypeMap;

	// The nexus creation consists of the following steps:
	// * create the object;
	// * fill it with the contents (the usual chain syntax);
	// * export it in the thread, thus initializing it and making it
	//   visible throughout the app. After that the nexus can't be changed.
	//
	// Any encountered errors will be collected and gan be read back with
	// getErrors(), or will cause an Exception when the nexus is exported.
	//
	// After the nexus has been exported, it can not be modified any more
	// and any such attempts will throw an Exception. The catch is that
	// this exception may lead to memory leaks, so better just don't do it.
	//
	// @param name - name of the nexus, must be unique within the thread.
	Nexus(const string &name);

	// Mark this Nexus as going in the reverse direction ("upwards").
	// This has two implications:
	// * no queue size limit, no flow control
	// * this nexus will have a higher reading priority than the direct ones
	// May be used only until the Nexus is exported or will throw an Exception.
	// @param on - flag: the direction is reverse
	// @return - the same Nexus
	Nexus *setReverse(bool on = true);

	// Mark this Nexus as unicast. The normal ("multicast") nexuses
	// send all the data passing through them to all the readers.
	// The unicast nexuses send each piece of the input to one
	// of the readers, chosen essentially at random. This allows
	// to implement the worker thread pools. A whole transaction
	// goes to the same reader.
	// May be used only until the Nexus is exported or will throw an Exception.
	// @param on - flag: the unicast mode is on
	// @return - the same Nexus
	Nexus *setUnicast(bool on = true);

	// Set the type of the nexus'es queue. The type will be deep-copied, with
	// all its row types copied. This leaves the original type for the
	// exclusive use of the creating thread. The created type will be
	// un-initialized and can have more row types added to it.
	// May be used only until the Nexus is exported or will throw an Exception.
	// @param rst - the type to set
	// @return - the same Nexus
	Nexus *setType(Onceref<RowSetType> rst);

	// Add a row type to the nexus'es queue.
	// May be used only until the Nexus is exported or will throw an Exception.
	// @param rtype - row type to add
	// @return - the same Nexus
	Nexus *addRow(const string &rname, const_Autoref<RowType>rtype);

	// Export a row type through the nexus. It won't be a part of the
	// queue, just a row type that can be imported by the other threads.
	// The type will be copied into the nexus, leaving the original
	// instance for the exclusive use of the creating thread.
	// May be called only until the Nexus is exported or will throw an Exception.
	//
	// @param name - name of the row type, these are in a separate namespace from
	//         the row set type of the queue
	// @param rtype - row type to export
	// @return - the same Nexus
	Nexus *exportRowType(const string &name, Onceref<RowType> rtype);

	// Export a table type through the nexus. It can be imported
	// by the other threads.
	// The type will be copied into the nexus, leaving the original
	// instance for the exclusive use of the creating thread.
	// May be called only until the Nexus is exported or will throw an Exception.
	//
	// @param name - name of the table type, these are in a separate namespace from
	//         the row types
	// @param tt - table type to export
	// @return - the same Nexus
	Nexus *exportTableType(const string &name, Onceref<TableType> tt);

	// Get the collected errors.
	Erref getErrors() const
	{
		return err_;
	}

	// Get the name
	const string &getName() const
	{
		return name_;
	}

	// Check whether the nexus is exported.
	bool isExported() const
	{
		return !tname_.empty();
	}

	// Check whether the nexus is reverse, i.e. the its queue is pointed
	// upwards.
	bool isReverse() const
	{
		return reverse_;
	}

	// Check whether the nexus is unicast.
	bool isUnicast() const
	{
		return unicast_;
	}

protected:
	// Throw an Exception if the nexus has been already exported.
	void assertNotExported();

	string tname_; // name of the thread that owns this nexus
	string name_;

	Erref err_; // the collected errors
	Autoref<RowSetType> type_; // the type of the nexus's main queue
	RowTypeMap rowTypes_; // the collection of row types
	TableTypeMap tableTypes_; // the collection of table types

	bool reverse_; // Flag: this nexus's main queue is pointed upwards
	bool unicast_; // Flag: each row goes to only one reader, as opposed to copied to all readers

private:
	Nexus();
	Nexus(const Nexus &);
	void operator=(const Nexus &);
};

}; // TRICEPS_NS

#endif // __Triceps_Nexus_h__
