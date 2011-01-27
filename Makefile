
.DEFAULT_GOAL = all

all clean test:
	$(MAKE) -C core $@
	$(MAKE) -C perl/Biceps $@

clobber:
	$(MAKE) -C core $@
	#$(MAKE) -C perl/Biceps $@

install uninstall:
	#$(MAKE) -C perl/Biceps $@
