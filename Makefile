#
# Provides targets to build code with SDCC, generate documentation etc.
#
# | Target          | Function                                          |
# |-----------------|---------------------------------------------------|
# | build (default) | Builds a .hex file and dependencies               |
# | all             | Builds a .hex file and every .c library           |
# | dbc             | Builds C headers from Vector dbc files            |
# | printEnv        | Used by scripts to determine project settings     |
# | uVision         | Run uVisionupdate.sh                              |
# | html            | Build all html documentation under doc/           |
# | pdf             | Build all pdf documentation under doc/            |
# | gh-pages        | Assemble all docs for GitHub Pages publishing     |
# | clean-build     | Remove build output                               |
# | clean-doc       | Remove doxygen output                             |
# | clean           | Clean everything                                  |
#
# Override the following settings in Makefile.local if needed.
#
# | Assignment      | Function                                          |
# |-----------------|---------------------------------------------------|
# | AWK             | The awk interpreter                               |
# | BUILDDIR        | SDCC output directory                             |
# | CC              | Compiler                                          |
# | CFLAGS          | Compiler flags                                    |
# | CPP             | C preprocesser used by several scripts            |
# | CONFDIR         | Location for the library configuration files      |
# | LIBPROJDIR      | Path to the library project                       |
# | CANPROJDIR      | Path to the CAN project                           |
# | DBCDIR          | Location for generated DBC headers                |
# | DOC_ALL_TARGETS | All doc/ subtargets (ecu, dbc)                    |
# | DOC_PUB_TARGETS | All gh-pages/ subtargets (ecu)                    |
# | GENDIR          | Location for generated code                       |
# | INCDIR          | Include directory for contributed headers         |
# | LIBDIR          | Path to the library sources                       |
# | OBJSUFX         | The file name suffix for object files             |
# | HEXSUFX         | The file name suffix for intel hex files          |
# | DATE            | System date, for use when hg is not available     |
# | VERSION         | Version of the project                            |
# | SRC             | The list of source files from this project        |
# | PROJECT         | The name of this project                          |
#

# Locate related projects.
LIBPROJDIR=	hsk-libs

# Include shared defaults
include ${LIBPROJDIR}/Makefile.include

# Build with SDCC.
CFLAGS+=	-I${LIBDIR}

# Library project configuration files.
CONFDIR:=	${LIBPROJDIR}/${CONFDIR}

# Include directories from the related projects.
INCDIR:=	${LIBPROJDIR}/${INCDIR}
LIBDIR=		${LIBPROJDIR}/src

# Documentation subtargets
DOC_ALL_TARGETS=ecu dbc

# Documenation to publish on GitHub Pages
DOC_PUB_TARGETS=ecu

# List of source files for generating dependencies documentation.
SRC:=		$(shell find src/ -name \*.\[hc] -o -name \*.txt)
SRC!=		find src/ -name \*.\[hc] -o -name \*.txt

#
# No more overrides.
#

# Local config
_LOCAL_MK:=	$(shell test -f Makefile.local || touch Makefile.local)
_LOCAL_MK!=	test -f Makefile.local || touch Makefile.local ; echo

# Gmake style, works with FreeBSD make, too
include Makefile.local

build:

.PHONY: ${GENDIR}/sdcc.mk ${GENDIR}/dbc.mk ${GENDIR}/build.mk

# Create the generated content directory
${GENDIR}:
	@mkdir -p ${GENDIR}

# Configure SDCC
${GENDIR}/sdcc.mk: ${GENDIR}
	@env CC="${CC}" sh ${LIBPROJDIR}/scripts/sdcc.sh ${CONFDIR}/sdcc > $@

# Generate dbc
${GENDIR}/dbc.mk: ${GENDIR}
	@sh ${LIBPROJDIR}/scripts/dbc.sh ${CANPROJDIR}/ > $@

# Generate build
${GENDIR}/build.mk: dbc ${GENDIR}
	@env CPP="${CPP}" \
	     ${AWK} -f ${LIBPROJDIR}/scripts/build.awk \
	            -vOBJSUFX="${OBJSUFX}" -vBINSUFX="${HEXSUFX}" \
                    src/ ${LIBDIR}/ -DSDCC -I${INCDIR}/ -I${LIBDIR}/ \
                    -I${GENDIR}/ > $@

.PHONY: build all dbc

# Generate headers from CANdbs
dbc: ${GENDIR}/dbc.mk
	@${MAKE} DBCDIR=${DBCDIR} -f ${GENDIR}/dbc.mk $@

${DBCDIR}: dbc

# Perform build stage
build all: ${GENDIR}/sdcc.mk ${GENDIR}/build.mk dbc
	@env CC="${CC}" CFLAGS="${CFLAGS}" OBJDIR="${BUILDDIR}/" \
	     ${MAKE} -rf ${GENDIR}/sdcc.mk -f ${GENDIR}/build.mk $@

.PHONY: printEnv uVision µVision

printEnv:
	@echo export PROJECT=\"${PROJECT}\"
	@echo export LIBPROJDIR=\"${LIBPROJDIR}\"
	@echo export CANPROJDIR=\"${CANPROJDIR}\"
	@echo export GENDIR=\"${GENDIR}\"
	@echo export INCDIR=\"${INCDIR}\"
	@echo export LIBDIR=\"${LIBDIR}\"
	@echo export CPP=\"${CPP}\"
	@echo export AWK=\"${AWK}\"

uVision µVision:
	@sh uVisionupdate.sh

# Documentation sources
doc/ecu: ${SRC} doxygen.conf
doc/dbc: ${DBCDIR} ${CONFDIR}/doxygen.dbc

# Doxygen targets
${DOC_ALL_TARGETS:C,^,doc/,}: ${CONFDIR}/doxygen.common
	@rm -rf "${.TARGET}"
	@mkdir -p "${.TARGET}"
	@echo 'PROJECT_NAME="${PROJECT}"'               >> "${.TARGET}"/.conf
	@echo 'PROJECT_NUMBER=${VERSION}'               >> "${.TARGET}"/.conf
	@echo 'OUTPUT_DIRECTORY="${.TARGET}/"'          >> "${.TARGET}"/.conf
	@echo 'WARN_LOGFILE="${.TARGET}/warnings.log"'  >> "${.TARGET}"/.conf
	@cat ${CONFDIR}/doxygen.common ${.ALLSRC:[-2]} ${.TARGET}/.conf | \
	 doxygen -

# PDF targets
${DOC_ALL_TARGETS:C,^,doc/,:C,$$,/latex/refman.pdf,}: ${.TARGET:H:H}
	@cd "${.TARGET:H}" && ${MAKE}

# GitHub Pages targets
${DOC_PUB_TARGETS:C,^,gh-pages/,}: doc/${.TARGET:T} doc/${.TARGET:T}/latex/refman.pdf
	@rm -rf "${.TARGET}"
	@cp -r "doc/${.TARGET:T}/html" "${.TARGET}"
	@cp "${.ALLSRC:[-1]}" "${.TARGET}/${PROJECT}.pdf"

# Documentation meta targets
html: ${DOC_ALL_TARGETS:C,^,doc/,}
pdf: ${DOC_ALL_TARGETS:C,^,doc/,:C,$$,/latex/refman.pdf,}
gh-pages: ${DOC_PUB_TARGETS:C,^,gh-pages/,}

.PHONY: clean clean-doc clean-build

clean: clean-doc clean-build

clean-doc:
	@rm -rf doc/*

clean-build:
	@rm -rf ${BUILDDIR}/* ${GENDIR}/*
