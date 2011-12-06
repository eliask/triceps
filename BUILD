How to build Triceps.
=====================

The tested build environment is Linux Fedora 11. The Perl build system
should make it work automatically on the other Unix environments as
well.

Prerequisites
-------------

Currently you must use the GNU Linux toolchain: GNU make, GNU C++ 
compiler, valgrind.

Versioning
----------

At the moment this is an experimental project, and there is no
versioning. The API may change in any way at any moment.

If you build some production code with Triceps, simply include the
Triceps shared library that was used to build it into your
deliverables. It's best to define a custom LIBRARY name to guarantee
its uniqueness. Put the shared library in a known directory relative
to your binary and build your binary with the appropriate -rpath
setting. For example, if they are in the same directory, use
"-Wl,-rpath='$$ORIGIN/.".  This way each project is free to have its
own version of Triceps shared library.

If you are concerned that your object files may later get mixed in the
same binary with other object files using a different version of
Triceps, also change the setting of TRICEPS_NS to a custom value.

Configurables
-------------

Currently there is no ./configure script and all the configuration
changes have to be done by hand. Three most important places to change
the configuration are the files cpp/Makefile.inc, cpp/common/Conf.h
and perl/Triceps/Makefile.PL. Makefile.inc and Makefile.PL need to
be edited consistently, otherwise the code will not build or will crash.
The extra defines in CFLAGS in Makefile.inc can be used to override
the macros defined in Conf.h.

The Conf.h macros are:

	TRICEPS_NS - C++ namespace used by Triceps

Makefile.inc and Makefile.PL settings:

    TRICEPS_NSPR4 and -lnspr4 - enables the use of NSPR4 library
	(primarily for the atomic operations). Enabled by default, disable
	if you don't have the NSPR4 library.

Other Makefile.inc settings:

	LIBRARY - the base name of the library files

Build
-----

To build:

	make all
	make test

The C++ libraries will be created under cpp/build.
The Perl libraries will be created under perl/Triceps/blib.

The tests are normally run with valgrind for the C++ part, without valgrind
for the Perl part.

[XXX install and uninstall dont' work yet]
To install:

	make install

To uninstall:

	make uninstall


Other interesting make targets:

	clobber - remove the object files, forcing the libraries to be
	rebuilt

	mktest - build the C++ unit tests, this requires that the
	libraries are already built

	vtest - run the unit tests with valgrind, checking for leaks and
	memory corruption

	qtest - run the unit tests quickly, without valgrind

	release - export from SVN a clean copy of the code and create
		a release package. The package name will be triceps-<version>.tgz,
		where the <version> is taken from the SVN directory name, from
		where the current directory is checked out.
