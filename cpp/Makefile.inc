
# The base settings that are always needed.
TRICEPS_CONF =
TRICEPS_XLIB = -lpthread

# configuration settings

# The NSPR library is a pain. In some distributions it's using the name,
# including the include directory name "nspr4". In some it's just "nspr".
# The difference in the include directory is a major pain and gets
# handled by the setting of TRICEPS_NSPR. If it's not set at all,
# NSPR won't be used. Instead an alternative portable implementation
# of atomic integers that uses a mutex will be used.
#
# use the NSPR4 library, named as such
TRICEPS_CONF += -DTRICEPS_NSPR=4
TRICEPS_XLIB += -lnspr4
# use the NSPR4 library, named simply "nspr", auto-found
# TRICEPS_CONF += -DTRICEPS_NSPR=0 $(shell pkg-config --cflags nspr)
# TRICEPS_XLIB += $(shell pkg-config --libs nspr)

# use a different namespace (instead of Triceps)
# TRICEPS_CONF += -DTRICEPS_NS=name

# do not use the glibc stack tracing library
# TRICEPS_CONF += -DTRICEPS_BACKTRACE=false

# base name of the Triceps library
LIBRARY := triceps

OBJEXT := .o
BINEXT := 
BUILDDIR := build
CPPFLAGS := -I.. $(TRICEPS_CONF)
CFLAGS := -g -fPIC -pthread -rdynamic $(CPPFLAGS) -Wall -Wno-sign-conversion -Wno-sign-compare -Werror $(TRICEPS_CONF)
CXXFLAGS := $(CFLAGS)
LDFLAGS := -L../build -l$(LIBRARY) $(TRICEPS_XLIB)
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
