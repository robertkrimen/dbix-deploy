.PHONY: all test time clean distclean dist distcheck upload distupload

all: test

dist distclean test tardist: Makefile
	make -f $< $@

test:
	TEST_DBIx_Deploy_PostgreSQL_superdatabase=default TEST_DBIx_Deploy_PostgreSQL_user=default \
	TEST_DBIx_Deploy_MySQL_superdatabase=default TEST_DBIx_Deploy_MySQL_user=default \
	make -f $< $@

Makefile: Makefile.PL
	perl $<

clean: distclean

reset: clean
	-dropdb -U postgres _deploy
	-dropuser -U postgres _deployusername
	-mysqladmin -fu root drop _deploy
	perl Makefile.PL
	$(MAKE) test
