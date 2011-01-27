
.DEFAULT_GOAL = all

all clean test: perl/Biceps/Makefile
	$(MAKE) -C core $@
	$(MAKE) -C perl/Biceps $@

clobber:
	$(MAKE) -C core $@
	#$(MAKE) -C perl/Biceps $@

install uninstall:
	#$(MAKE) -C perl/Biceps $@

perl/Biceps/Makefile: perl/Biceps/Makefile.PL
	cd perl/Biceps && perl Makefile.PL
