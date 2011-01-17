
OBJEXT := .o
BUILDDIR := build
CPPFLAGS := -I..
CFLAGS := -O -g -fPIC $(CPPFLAGS)
CXXFLAGS := $(CFLAGS)
RANLIB := ranlib

LIBRARY := biceps
SHLIB := lib$(LIBRARY).so
ARLIB := lib$(LIBRARY).a

# so that the targets defined here won't override "all"
.DEFAULT_GOAL := all

$(BUILDDIR):
	mkdir $(BUILDDIR)
