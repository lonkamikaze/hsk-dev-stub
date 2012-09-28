#!/bin/sh -f

IFS='
'

project=$(basename $PWD)
PROJECT=$(echo $project | tr '[:lower:]' '[:upper:]')
LIBDIR=$(make -VLIBDIR 2> /dev/null)
if [ -z "$LIBDIR" ]; then
	eval "$(sed -Ene '/LIBDIR=/s/LIBDIR=[[:space:]]*(.*)/LIBDIR="\1"/p' \
			Makefile Makefile.local)"
fi
CANDIR=$(make -VCANDIR 2> /dev/null)
if [ -z "$CANDIR" ]; then
	eval "$(sed -Ene '/CANDIR=/s/CANDIR=[[:space:]]*(.*)/CANDIR="\1"/p' \
			Makefile Makefile.local)"
fi
libs=$(basename ${LIBDIR%/src})
LIBS=$(echo $libs | tr '[:lower:]' '[:upper:]')

# Get required .c files from the libraries.
for lib in $(
	find src/ -name \*.c | xargs awk -f scripts/includes.awk src/ "$LIBDIR/" \
		| sed -ne "/^src\//d" -e "s,\.[ch]:.*,.c,p" | sort -u); do
	test ! -f "$lib" && continue
	libdeps="$libdeps
-insert:File
-selectInserted
-insert:FileName=${lib##*/}
-insert:FileType=1
-insert:FilePath=../$lib"
	if grep -Eq '^[[:space:]]*#[[:space:]]*pragma[[:space:]](.*[[:space:]])?asm($|[[:space:]].*)' "$lib"; then
		libdeps="$libdeps
-insert:FileOption
-selectInserted
-insert:CommonProperty
-selectInserted
-insert:UseCPPCompiler=2
-insert:RVCTCodeConst=0
-insert:RVCTZI=0
-insert:RVCTOtherData=0
-insert:ModuleSelection=0
-insert:IncludeInBuild=2
-insert:AlwaysBuild=2
-insert:GenerateAssemblyFile=1
-insert:AssembleAssemblyFile=1
-insert:PublicsOnly=2
-insert:StopOnExitCode=11
-insert:CustomArgument
-insert:IncludeLibraryModules
-insert:BankNo=65535
-select:..
-insert:File51
-selectInserted
-insert:C51
-selectInserted
-insert:RegisterColoring=2
-insert:VariablesInOrder=2
-insert:IntegerPromotion=2
-insert:uAregs=2
-insert:UseInterruptVector=2
-insert:Fuzzy=8
-insert:Optimize=10
-insert:WarningLevel=3
-insert:SizeSpeed=2
-insert:ObjectExtend=2
-insert:ACallAJmp=2
-insert:InterruptVectorAddress=0
-insert:VariousControls
-selectInserted
-insert:MiscControls
-insert:Define
-insert:Undefine
-insert:IncludePath
-select:../../../.."
	fi
	libdeps="$libdeps$IFS-select:.."
	incpaths="$incpaths${incpaths:+;}../${lib%/*}"
	incfiles="$incfiles${IFS}$lib"
done

overlays="$(awk -f scripts/overlays.awk $incfiles $(find src/ -name \*.c))"

cp uVision/hsk_dev.uvproj uVision/hsk_dev.uvproj.bak
awk -f scripts/xml.awk uVision/hsk_dev.uvproj.bak \
	-search:TargetName \
	-set:"$PROJECT" \
	-select:/ \
	-search:OutputName \
	-set:"$project" \
	-select:/ \
	-search:IncludePath \
	-set:"../$LIBDIR;../$CANDIR" \
	-select:/ \
	-search:OverlayString \
	-set:"$overlays" \
	-select:/ \
	-search:"Group/GroupName=HSK_LIBS/.." \
	-search:IncludePath \
	-set:"$incpaths" \
	-select:/ \
	-search:"Group/GroupName=$LIBS/../Files" \
	-delete \
	-select:/ \
	-search:"Group/GroupName=$LIBS/.." \
	-insert:"Files" \
	-selectInserted \
	$libdeps \
	-select:/ \
	-print > uVision/hsk_dev.uvproj \
		&& rm uVision/hsk_dev.uvproj.bak \
		|| mv uVision/hsk_dev.uvproj.bak uVision/hsk_dev.uvproj

