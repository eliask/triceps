How to build Triceps.
=====================

The tested build environment is Linux Fedora 11. It should work
automatically on the other Linux systems as well but has not been tested
much in practice.

The build should work on the other Unix environments too but would
require some manual configuration for the available libraries,
and has not been tested either.

The tested Perl version is 5.10.0, and should work on any later version
as well. With the earlier versions your luck may vary. The Makefile.PL
has bben configured to require at least 5.8.0 but you may edit it and
try building on the older versions.

The normal build expectation is for the 64-bit machines. The 32-bit
machines should work (and the code even includes the special cases for
them) but have been untested at the moment.

Prerequisites
-------------

Currently you must use the GNU Linux toolchain: GNU make, GNU C++ 
compiler (version 4.4.1 has been tested), valgrind. You can build
without valgrind by running only the non-valgrind tests.

Versioning
----------

At the moment this projects structure is tilted towards the ease of innovation,
and there is no versioning. The API may change in any way at any moment.

If you build some production code with Triceps, simply include the
Triceps shared library that was used to build it into your
deliverables. It's best to define a custom LIBRARY name (see
Configurables below) to guarantee its uniqueness, in case if the
binary is ever to run on a machine where some Triceps version has
been installed in the system-wide directories.

To build the C++ projects with this library,
put the shared library in a known directory relative
to your binary and build your binary with the appropriate -rpath
setting. For example, if they are in the same directory, use
"-Wl,-rpath='$$ORIGIN/.".  This way each project is free to have its
own version of Triceps shared library. Of course, the static linking
also works.

If you are concerned that your object files may later get mixed in the
same binary with other object files using a different version of
Triceps, also change the setting of TRICEPS_NS to a custom value.

XXX custom packaging for Perl. Merge with installation.

Configurables
-------------

Currently there is no ./configure script and all the configuration
changes have to be done by hand. Three most important places to change
the configuration are the files cpp/Makefile.inc, cpp/common/Conf.h
and perl/Triceps/Makefile.PL. Makefile.inc and Makefile.PL need to
be edited consistently, otherwise the code will not build or will crash.
The extra defines in CFLAGS in Makefile.inc can be used to override
the macros defined in Conf.h.

The cpp/common/Conf.h macros are:

	TRICEPS_NS - C++ namespace used by Triceps.

	TRICEPS_BACKTRACE - flag: use the glibc backtrace() functionality
	to make the messages in the Triceps exceptions more useful.

cpp/Makefile.inc and Makefile.PL settings:

    TRICEPS_NSPR4 and -lnspr4 in LIBS - enables the use of NSPR4 library
	(primarily for the atomic operations). Enabled by default, disable
	if you don't have the NSPR4 library.

	LIBRARY and MYEXTLIB - the base name of the C++ library files.

Build
-----

To build:

	make all
	make test

The C++ libraries will be created under cpp/build.
The Perl libraries will be created under perl/Triceps/blib.

The tests are normally run with valgrind for the C++ part, without valgrind
for the Perl part. The reason is that Perl produces lots of false positives,
and the suppressions depend on particular Perl versions and are not
exactly reliable.

Other interesting make targets:

	clobber - remove the object files, forcing the libraries to be
		rebuilt next time

	mktest - build the C++ unit tests, this requires that the
		libraries are already built

	vtest - run the unit tests with valgrind, checking for leaks and
		memory corruption

	qtest - run the unit tests quickly, without valgrind

	release - export from SVN a clean copy of the code and create
		a release package. The package name will be triceps-<version>.tgz,
		where the <version> is taken from the SVN directory name, from
		where the current directory is checked out.
		XXX builds docs


Building the documentation
--------------------------

If you have downloaded the release package of Triceps, the documentation
is already included it in the built form. The PDF and HTML versions are
available in doc/pdf and doc/html. It is also available online from
http://triceps.sf.net.

XXX how to build

Installation
------------

To install in the system-wide default Perl location:

	make install

To install under a particular subdirectory (here $HOME/inst):

	make install DESTDIR=$HOME/inst

Only the Perl files are installed, not the C++ files. If the files were 
installed not in the default Perl location, Perl would have to be run
with option -I; for example:

	perl -I $HOME/inst/usr/local/lib64/perl5/site_perl/5.10.0

(the exact path depends on your Perl version). The alternative way is to
specify the location inside the Perl scripts as

	use lib "$ENV{HOME}/inst/usr/local/lib64/perl5/site_perl/5.10.0";

(your exact location will vary depending on the Perl version and machine
architecture).

To play with small examples, it might be easier to not install at all
but put them directly into the directory perl/Triceps/t in the Triceps
distribution. In this case, use in them

	use ExtUtils::testlib;

to make Perl find the Triceps libraries directly in the build
directories.

To build your C++ code with Triceps, simply specify the location of Triceps
sources and built libraries with options -I and -L. For example:

	TRICEPSBASE=$(HOME)/srcs/triceps-0.99
	CFLAGS+= -I$(TRICEPSBASE)/cpp -L$(TRICEPSBASE)/cpp/build -ltriceps

If you build your code with the dynamic library, the best practice is to
copy the libtriceps.so to the same directory where your binary is
located and specify its location with the build flags:

	CFLAGS+="-Wl,-rpath='$$ORIGIN/."

It might be easier to build your code with the static library: just
instead of -ltriceps, link explicitly with
$(TRICEPSBASE)/cpp/build/libtriceps.a.

The uninstall luck varies with your version of Perl. If you're lucky,
the following command would perform the uninstall:

	make uninstall

(add DESTDIR if you used it for install). However in the recent Perl
versions the uninstall feature has been deprecated. At best it would
print the list of commands that can be used to perform the uninstall.
In Perl 5.10 the uninstall does not understand the DESTDIR setting, so
for that case the easiest way may be to delete the whole DESTDIR. Or
find the packaging list and remove the files listed there. The packaging
list is located in a file named like

	$DESTDIR/usr/local/lib64/perl5/site_perl/5.10.0/x86_64-linux-thread-multi/auto/Triceps/.packlist

again, depending on your exact Perl version and configuration.
