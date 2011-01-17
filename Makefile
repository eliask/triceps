
.DEFAULT_GOAL = all

# this brings the C++ part by a dependency
all clean clobber:
	$(MAKE) -C core $@
	#$(MAKE) -C perl $@

# the test may run the C++ only tests in the future too...
install test uninstall:
	#$(MAKE) -C perl $@
