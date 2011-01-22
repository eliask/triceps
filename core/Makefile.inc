
OBJEXT := .o
BINEXT := 
BUILDDIR := build
CPPFLAGS := -I..
CFLAGS := -g -fPIC -pthread -rdynamic $(CPPFLAGS)
CXXFLAGS := $(CFLAGS)
LDFLAGS := -L../build -lbiceps -lpthread
TESTLDFLAGS := $(LDFLAGS) -Wl,-rpath='$$ORIGIN/../../../build'

RANLIB := ranlib
VALGRIND := valgrind --leak-check=full -v

LIBRARY := biceps
SHLIB := lib$(LIBRARY).so
ARLIB := lib$(LIBRARY).a

# so that the targets defined here won't override "all"
.DEFAULT_GOAL := all

$(BUILDDIR):
	mkdir $(BUILDDIR)
