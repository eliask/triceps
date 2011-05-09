//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Tray.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::Tray		PACKAGE = Triceps::Tray
###################################################################################

void
DESTROY(WrapTray *self)
	CODE:
		// warn("Tray destroyed!");
		delete self;

# Since in C++ a tray is simply a deque, instead of providing all the methods, just
# provide a conversion to and from array

# Constructed in Unit::makeTray
# XXX add makeTray

# make a copy 
WrapTray *
copy(WrapTray *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Tray";
		clearErrMsg();
		Tray *t = self->get();
		RETVAL = new WrapTray(self->getParent(), new Tray(*t));
	OUTPUT:
		RETVAL

# XXX add toArray(), refill() - new contents from array, append() - add contents from array
# XXX add tests
