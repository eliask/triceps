
.DEFAULT_GOAL = all

all clean test qtest vtest: perl/Triceps/Makefile
	$(MAKE) -C cpp $@
	$(MAKE) -C perl/Triceps $@

clobber:
	$(MAKE) -C cpp $@
	#$(MAKE) -C perl/Triceps $@

install uninstall:
	#$(MAKE) -C perl/Triceps $@

perl/Triceps/Makefile: perl/Triceps/Makefile.PL
	cd perl/Triceps && perl Makefile.PL

release:
	./mkrelease
