BUILDDIR=	bin.sdcc
CC=		sdcc
CFLAGS=		-mmcs51 --xram-loc 0xF000 --xram-size 3072 -I${INCDIR} -I${LIBDIR}

INCDIR=		../hsk_libs/inc
LIBDIR=		../hsk_libs/src

OBJSUFX=	.rel
HEXSUFX=	.hex

DATE:=		$(shell date +%Y-%m-%d)
DATE!=		date +%Y-%m-%d

VERSION:=	$(shell hg tip 2> /dev/null | awk '/^changeset/ {print $$2}' || echo ${DATE})
VERSION!=	hg tip 2> /dev/null | awk '/^changeset/ {print $$2}' || echo ${DATE}

SRC:=		$(shell find src/ -name \*.\[hc] -o -name \*.txt)
SRC!=		find src/ -name \*.\[hc] -o -name \*.txt

PROJECT:=	$(shell pwd | xargs basename)
PROJECT!=	pwd | xargs basename

_LOCAL_MK:=	$(shell test -f Makefile.local || touch Makefile.local)
_LOCAL_MK!=	test -f Makefile.local || touch Makefile.local

include Makefile.local

build:

_BUILD_MK:=	$(shell sh scripts/build.sh src/ ${LIBDIR}/ > build.mk)
_BUILD_MK!=	sh scripts/build.sh src/ ${LIBDIR}/ > build.mk

# Gmake style, works with FreeBSD make, too
include build.mk

html: doc
	@rm -rf html
	@cp -r doc/html html

doc: ${SRC} doxygen.conf
	@rm -rf doc || true
	@mkdir -p doc
	@echo PROJECT_NUMBER=${VERSION} >> doc/.conf
	@cat doxygen.conf doc/.conf | doxygen -

pdf: pdf/${PROJECT}.pdf

pdf/${PROJECT}.pdf: doc/latex/refman.pdf
	@mkdir -p pdf
	@cp doc/latex/refman.pdf "pdf/${PROJECT}.pdf"

doc/latex/refman.pdf: doc
	@cd doc/latex/ && ${MAKE}

clean: clean-doc clean-build

clean-doc:
	@rm -rf doc || true

clean-build:
	@rm -rf ${BUILDDIR} || true

zip: pdf
	@hg status -A | awk '$$1 != "I" {sub(/. /, "${PROJECT}/"); print}' | (cd .. && zip ${PROJECT}.${DATE}.zip -\@ -r ${PROJECT}/pdf)

