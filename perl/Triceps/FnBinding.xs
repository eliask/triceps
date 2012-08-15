//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for FnBinding.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::FnBinding		PACKAGE = Triceps::FnBinding
###################################################################################

# The use is like this:
#
# $fnr = FnReturn->new(...);
# $bind = FnBinding->new(
#     name => "bind1", # used for the names of direct Perl labels
#     on => $fnr, # determines the type of return
#     unit => $unit, # needed only for the direct Perl code
#     labels => [
#         "name" => $label,
#         "name" => sub { ... }, # will directly create a Perl label
#     ]
# );
# $fnr->push($bind);
# $fnr->pop($bind);
# $fnr->pop();
# FnBinding->call( # create and push/call/pop right away
#     name => "bind1", # used for the names of direct Perl labels
#     on => $fnr, # determines the type of return
#     unit => $unit, # needed only for the direct Perl code
#     labels => [
#         "name" => $label,
#         "name" => sub { ... }, # will directly create a Perl label
#     ]
#     rowop => $rowop, # what to call can be a rowop
#     label => $label, # or a label and a row
#     row => $row, # a row may be an actual row
#     rowHash => { ... }, # or a hash
#     rowHash => [ ... ], # either an actual hash or its array form
#     rowArray => [ ... ], # or an array of values
# );
# $unit->callBound( # pushes all the bindings, does the call, pops
#     $rowop,
#     $fnr => $bind, ...
# );
#     
# 

void
DESTROY(WrapFnBinding *self)
	CODE:
		// warn("FnBinding destroyed!");
		delete self;

# check whether both refs point to the same object
int
same(WrapFnBinding *self, WrapFnBinding *other)
	CODE:
		clearErrMsg();
		FnBinding *f = self->get();
		FnBinding *of = other->get();
		RETVAL = (f == of);
	OUTPUT:
		RETVAL

# Args are the option pairs. The options are:
#
# XXX describe options, from the sample above
WrapFnBinding *
new(char *CLASS, ...)
	CODE:
		static char funcName[] =  "Triceps::FnBinding::new";
		Autoref<FnBinding> fbind;

		RETVAL = new WrapFnBinding(fbind);
	OUTPUT:
		RETVAL


