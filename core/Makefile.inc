
OBJEXT := .o
BINEXT := 
BUILDDIR := build
CPPFLAGS := -I..
CFLAGS := -g -fPIC -pthread -rdynamic $(CPPFLAGS) -Wall -Wno-sign-conversion -Wno-sign-compare
CXXFLAGS := $(CFLAGS)
LDFLAGS := -L../build -lbiceps -lpthread
TESTLDFLAGS := $(LDFLAGS) -L../utest/build -Wl,-rpath='$$ORIGIN/../../../build' \
	-lbiceps_utest -Wl,-rpath='$$ORIGIN/../../../utest/build'

RANLIB := ranlib
VALGRIND := valgrind --leak-check=full -v

LIBRARY := biceps
SHLIB := lib$(LIBRARY).so
ARLIB := lib$(LIBRARY).a

# so that the targets defined here won't override "all"
.DEFAULT_GOAL := all

$(BUILDDIR):
	mkdir $(BUILDDIR)
