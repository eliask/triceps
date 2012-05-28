DOCXML=docbook-xml-4.5CR3

all:
	[ -d $(DOCXML) ] || mkdir $(DOCXML)
	cd $(DOCXML) && unzip -o ../$(DOCXML).zip
	tar xjvf docbook-xsl-1.75.2.tar.bz2
	tar xzvf fop-0.95-bin.tar.gz
	unzip -o jai-1_1_3-lib.zip
	unzip -o offo-hyphenation-fop-stable_v1.2.zip
	tar xzvf xml-commons-resolver-1.2.tar.gz
	tar xzvf links.tgz
