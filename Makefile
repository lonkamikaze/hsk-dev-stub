#
# Provides targets to build code with SDCC, generate documentation etc.
#
# | Target          | Function
# |-----------------|---------------------------------------------------
# | build (default) | Builds a .hex file and dependencies
# | all             | Builds a .hex file and every .c library
# | printEnv        | Used by scripts to determine project settings
# | uVision         | Run uVisionupdate.sh
# | html            | Build html documentation
# | pdf             | Build pdf documentation
# | clean-build     | Remove build output
# | clean-doc       | Remove doxygen output
# | clean           | Clean everything
# | zip             | Create a .zip archive in the parent directory
#
# Override the following settings in Makefile.local if needed.
#
# | Assignment      | Function
# |-----------------|---------------------------------------------------
# | BUILDDIR        | SDCC output directory
# | CC              | Compiler
# | CFLAGS          | Compiler flags
# | CPP             | C preprocesser used by several scripts
# | LIBPROJDIR      | Path to the library project
# | CANPROJDIR      | Path to the CAN project
# | INCDIR          | Include directory for contributed headers
# | LIBDIR          | Path to the library sources
# | CANDIR          | Include directory for CAN DB headers
# | OBJSUFX         | The file name suffix for object files
# | HEXSUFX         | The file name suffix for intel hex files
# | DATE            | System date, for use when hg is not available
# | VERSION         | Version of the project
# | SRC             | The list of source files from this project
# | PROJECT         | The name of this project
#

# Build with SDCC.
BUILDDIR=	bin.sdcc
CC=		sdcc
CFLAGS=		-mmcs51 --peep-file ${LIBPROJDIR}/peeprules.sdcc --xram-loc 0xF000 --xram-size 3072 -I${INCDIR} -I${CANDIR} -I${LIBDIR}

# Sane default for uVisionupdate.sh.
CPP=		cpp

# Locate related projects.
LIBPROJDIR=	../hsk_libs
CANPROJDIR=	../CAN

# Include directories from the related projects.
INCDIR=		${LIBPROJDIR}/inc
LIBDIR=		${LIBPROJDIR}/src
CANDIR=		${CANPROJDIR}/src

# File name suffixes for sdcc/XC800_Fload.
OBJSUFX=	.rel
HEXSUFX=	.hex

# The system date format.
DATE:=		$(shell date +%Y-%m-%d)
DATE!=		date +%Y-%m-%d

# Use hg version with date fallback.
VERSION:=	$(shell hg tip 2> /dev/null | awk '/^changeset/ {print $$2}' || echo ${DATE})
VERSION!=	hg tip 2> /dev/null | awk '/^changeset/ {print $$2}' || echo ${DATE}

# List of source files for generating dependencies documentation.
SRC:=		$(shell find src/ -name \*.\[hc] -o -name \*.txt)
SRC!=		find src/ -name \*.\[hc] -o -name \*.txt

# Name of this project.
PROJECT:=	$(shell pwd | xargs basename)
PROJECT!=	pwd | xargs basename

#
# No more overrides.
#

_LOCAL_MK:=	$(shell test -f Makefile.local || touch Makefile.local)
_LOCAL_MK!=	test -f Makefile.local || touch Makefile.local

# Gmake style, works with FreeBSD make, too
include Makefile.local

build:

_BUILD_MK:=	$(shell sh ${LIBPROJDIR}/scripts/build.sh src/ ${LIBDIR}/ ${CANDIR}/ > build.mk)
_BUILD_MK!=	sh ${LIBPROJDIR}/scripts/build.sh src/ ${LIBDIR}/ ${CANDIR}/ > build.mk

# Gmake style, works with FreeBSD make, too
include build.mk

printEnv::
	@echo export PROJECT=\"${PROJECT}\"
	@echo export LIBPROJDIR=\"${LIBPROJDIR}\"
	@echo export CANPROJDIR=\"${CANPROJDIR}\"
	@echo export INCDIR=\"${INCDIR}\"
	@echo export LIBDIR=\"${LIBDIR}\"
	@echo export CANDIR=\"${CANDIR}\"
	@echo export CPP=\"${CPP}\"

uVision::
	@sh uVisionupdate.sh

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
	@hg status -A | awk '$$1 != "I" {sub(/. /, "${PROJECT}/"); print}' | (cd .. && zip ${PROJECT}-${VERSION}.zip -\@ -r ${PROJECT}/pdf)

