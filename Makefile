
.DEFAULT_GOAL = all

all clean test qtest vtest: perl/Biceps/Makefile
	$(MAKE) -C cpp $@
	$(MAKE) -C perl/Biceps $@

clobber:
	$(MAKE) -C cpp $@
	#$(MAKE) -C perl/Biceps $@

install uninstall:
	#$(MAKE) -C perl/Biceps $@

perl/Biceps/Makefile: perl/Biceps/Makefile.PL
	cd perl/Biceps && perl Makefile.PL
