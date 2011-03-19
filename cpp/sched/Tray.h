//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Tray is an ordered collection of rowops.

#ifndef __Biceps_Tray_h__
#define __Biceps_Tray_h__

#include <common/Common.h>
#include <mem/Autoref.h>
#include <sched/Rowop.h>
#include <deque>

namespace BICEPS_NS {

// A tray stores the row operations in the order they were appended.
// The row operations may be on mixed labels and mixed row types.
// The word "tray" comes from the following methafor: when new
// data is pushed into a table, some change notifications fall out
// of it. By putting a tray under it these falling ops can be collected
// and sent into the further processing.
class Tray : public Starget, public deque< Autoref<Rowop> >
{
public:
	Tray()
	{}

	Tray(const Tray &orig) :
		deque< Autoref<Rowop> >(orig)
	{ }
};

}; // BICEPS_NS

#endif // __Biceps_Tray_h__
