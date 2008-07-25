.PHONY: all test time clean distclean dist distcheck upload distupload prompt

all: test

dist:
	rm -rf inc META.y*ml
	perl Makefile.PL
	$(MAKE) -f Makefile dist

distclean tardist: Makefile
	$(MAKE) -f $< $@

test: Makefile
	TEST_DBIx_Deploy_PostgreSQL_superdatabase=default TEST_DBIx_Deploy_PostgreSQL_user=default \
	TEST_DBIx_Deploy_MySQL_superdatabase=default TEST_DBIx_Deploy_MySQL_user=default \
	TEST_RELEASE=1 $(MAKE) -f $< $@
#	TRACE_DBIX_DEPLOY=1 TEST_RELEASE=1 prove -v t/*.t

Makefile: Makefile.PL
	perl $<

clean: distclean

reset: clean
	-dropdb -U postgres _deploy
	-dropuser -U postgres _deployusername
	-mysqladmin -fu root drop _deploy
	perl Makefile.PL
	$(MAKE) test

prompt:
	TRY_IT_OUT=1 perl ./t/002-prompt.t
