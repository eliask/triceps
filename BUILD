How to build Biceps.
====================

The tested build environment is Linux Fedora 11. The Perl build system
should make it work automatically on the other Unix environments as
well.

One known deficiency of the Fedora 11 is that its Perl package doesn't
include the module Test::Simple. Without it the tests won't work.
Install it from CPAN
<http://search.cpan.org/~mschwern/Test-Simple/lib/Test/Simple.pm>.

Prerequisites
-------------

Currently you must use the GNU Linux toolchain: GNU make, GNU C++ 
compiler, valgrind.

Versioning
----------

At the moment this is an experimental project, and there is no
versioning. The API may change in any way at any moment.

If you build some production code with Biceps, simply include the
Biceps shared library that was used to build it into your
deliverables. It's best to define a custom LIBRARY name to guarantee
its uniqueness. Put the shared library in a known directory relative
to your binary and build your binary with the appropriate -rpath
setting. For example, if they are in the same directory, use
"-Wl,-rpath='$$ORIGIN/.".  This way each project is free to have its
own version of Biceps shared library.

If you are concerned that your object files may later get mixed in the
same binary with other object files using a different version of
Biceps, also change the setting of BICEPS_NS to a custom value.

Configurables
-------------

Currently there is no ./configure script and all the configuration
changes have to be done by hand. Two most important places to change
the configuration are the files core/Makefile.inc and
core/common/Conf.h. The extra defines in CFLAGS in Makefile.inc can be
used to override the macros defined in Conf.h.

The Conf.h macros are:

	BICEPS_NS - C++ namespace used by Biceps

Other Makefile.inc settings:

	LIBRARY - the base name of the library files

Build
-----

[XXX Future, doesn't work yet]

To build:

	make all
	make test

To install:

	make install

To uninstall:

	make uninstall

[XXX Now]

At the moment only the C++ part located under core/ builds. To build:

	make all
	make test

The libraries will be created under core/build.


Other interesting make targets:

	clobber - remove the object files, forcing the libraries to be
	rebuilt

	mktest - build the C++ unit tests, this requires that the
	libraries are already built

	vtest - run the unit tests with valgrind, checking for leaks and
	memory corruption

	qtest - run the unit tests quickly, without valgrind
