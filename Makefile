BUILDDIR=	bin.sdcc
CC=		sdcc
CFLAGS=		-mmcs51 --peep-file ${LIBPROJDIR}/peeprules.sdcc --xram-loc 0xF000 --xram-size 3072 -I${INCDIR} -I${CANDIR} -I${LIBDIR}

LIBPROJDIR=	../hsk_libs
CANPROJDIR=	../CAN

INCDIR=		${LIBPROJDIR}/inc
LIBDIR=		${LIBPROJDIR}/src
CANDIR=		${CANPROJDIR}/src

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

_BUILD_MK:=	$(shell sh ${LIBPROJDIR}/scripts/build.sh src/ ${LIBDIR}/ ${CANDIR}/ > build.mk)
_BUILD_MK!=	sh ${LIBPROJDIR}/scripts/build.sh src/ ${LIBDIR}/ ${CANDIR}/ > build.mk

# Gmake style, works with FreeBSD make, too
include build.mk

printEnv:
	@echo export PROJECT=\"${PROJECT}\"
	@echo export LIBPROJDIR=\"${LIBPROJDIR}\"
	@echo export CANPROJDIR=\"${CANPROJDIR}\"
	@echo export INCDIR=\"${INCDIR}\"
	@echo export LIBDIR=\"${LIBDIR}\"
	@echo export CANDIR=\"${CANDIR}\"
	@echo export CPP=\"${CPP}\"

html: doc
	@rm -rf html
	@cp -r doc/html html

doc: ${SRC} doxygen.conf
	@rm -rf doc || true
	@mkdir -p doc
	@echo PROJECT_NAME=${PROJECT} > doc/.conf
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

