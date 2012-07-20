
# configuration settings
# -DTRICEPS_NSPR4: use the NSPR4 library -lnspr4
TRICEPS_CONF=-DTRICEPS_NSPR4

# external libraries, matching TRICEPS_CONF
# (also adjust perl/Triceps/Makefile.PL)
TRICEPS_XLIB=-lnspr4

# base name of the Triceps library
LIBRARY := triceps

OBJEXT := .o
BINEXT := 
BUILDDIR := build
CPPFLAGS := -I.. $(TRICEPS_CONF)
CFLAGS := -g -fPIC -pthread -rdynamic $(CPPFLAGS) -Wall -Wno-sign-conversion -Wno-sign-compare -Werror $(TRICEPS_CONF)
CXXFLAGS := $(CFLAGS)
LDFLAGS := -L../build -l$(LIBRARY) $(TRICEPS_XLIB) -lpthread
TESTLDFLAGS := $(LDFLAGS) -L../utest/build -Wl,-rpath='$$ORIGIN/../../../build' \
	-ltriceps_utest -Wl,-rpath='$$ORIGIN/../../../utest/build'

RANLIB := ranlib
VALGRIND := valgrind --leak-check=full -v

SHLIB := lib$(LIBRARY).so
ARLIB := lib$(LIBRARY).a

# so that the targets defined here won't override "all"
.DEFAULT_GOAL := all

$(BUILDDIR):
	mkdir $(BUILDDIR)

getconf:
	@echo "$(TRICEPS_CONF)"

getxlib:
	@echo "$(TRICEPS_XLIB)"

getlib:
	@echo "$(LIBRARY)"
