#!/bin/sh -f

IFS='
'

eval "$(make printEnv)"
project="$PROJECT"
PROJECT="$(echo "$project" | tr '[:lower:]' '[:upper:]')"

# Get required .c files from the libraries.
echo "Getting .c files to include ..." 1>&2
libs="$(
	find src/ -name \*.c | xargs awk -f $LIBPROJDIR/scripts/includes.awk src/ "$LIBDIR/" \
		| sed -ne "/^src\//d" -e "s,\.[ch]:.*,.c,p" | sort -u)"
echo "$libs" | sed 's/^/	/' 1>&2

echo "Preparing header include directories ..." 1>&2
LIBDIR="$(echo "$LIBDIR" | tr '/' '\\')"
CANDIR="$(echo "$CANDIR" | tr '/' '\\')"

# Create groups
echo "Creating library groups ..." 1>&2
oldGroupname=
for lib in $libs; do
	test ! -f "$lib" && continue
	groupname="${lib%/*}"
	groupname="HSK_LIBS::$(echo "${groupname##*/}" | tr '[[:lower:]]' '[[:upper:]]')"
	# Open new group
	if [ "$oldGroupname" != "$groupname" ]; then
		echo "	Create group: $groupname" 1>&2
		oldGroupname="$groupname"
		hasOptions=
		libdeps="$libdeps
			-insert:Group
			-selectInserted
			-insert:GroupName=$groupname
			-select:.."
	fi
	if [ -z "$hasOptions" ]; then
		if grep -Eq '^[[:space:]]*#[[:space:]]*pragma[[:space:]](.*[[:space:]])?asm($|[[:space:]].*)' "$lib"; then
			echo "	Activate assembly: $groupname" 1>&2
			hasOptions=1
			libdeps="$libdeps
				-search:Group/GroupName=$groupname/..
				-insert:GroupOption
				-selectInserted
				-insert:CommonProperty
				-selectInserted
				-insert:UseCPPCompiler=0
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
				-insert:Group51
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
				-select:../..
				-insert:Ax51
				-selectInserted
				-insert:UseMpl=2
				-insert:UseStandard=2
				-insert:UseCase=2
				-insert:UseMod51=2
				-insert:VariousControls
				-selectInserted
				-insert:MiscControls
				-insert:Define
				-insert:Undefine
				-insert:IncludePath
				-select:../../../../.."
		fi
	fi
done

echo "Adding files ..." 1>&2
libdeps="$libdeps
	-search:Group/GroupName=HSK_LIBS::*/..
	-insert:Files
	-select:/
	-search:Group/GroupName=HSK_LIBS::HSK_BOOT/../Files
	-insert:File
	-selectInserted
	-insert:FileName=startup.a51
	-insert:FileType=2
	-insert:FilePath=..\\$LIBDIR\\hsk_boot\\startup.a51"

for lib in $libs; do
	test ! -f "$lib" && continue
	incfiles="$incfiles${IFS}$lib"
	groupname="${lib%/*}"
	groupname="HSK_LIBS::$(echo "${groupname##*/}" | tr '[[:lower:]]' '[[:upper:]]')"
	filename="${lib##*/}"
	filepath="$(echo "$lib" | tr '/' '\\')"
	echo "	Add file: $groupname/$filename" 1>&2
	libdeps="$libdeps
		-select:/
		-search:Group/GroupName=$groupname/../Files
		-insert:File
		-selectInserted
		-insert:FileName=$filename
		-insert:FileType=1
		-insert:FilePath=..\\$filepath"
done

echo "Getting call tree changes for overlay optimisation ..." 1>&2
overlays="$(awk -f ${LIBPROJDIR}/scripts/overlays.awk $incfiles $(find src/ -name \*.c))"
echo "$overlays" | sed -e 's/^/	/' -e 's/[[:cntrl:]]$//' 1>&2

echo "Updating uVision/hsk_dev.uvproj ..." 1>&2
cp uVision/hsk_dev.uvproj uVision/hsk_dev.uvproj.bak
awk -f ${LIBPROJDIR}/scripts/xml.awk uVision/hsk_dev.uvproj.bak \
	-search:TargetName \
	-set:"$PROJECT" \
	-select:/ \
	-search:OutputName \
	-set:"$project" \
	-select:/ \
	-search:IncludePath \
	-set:"..\\$LIBDIR;..\\$CANDIR" \
	-select:/ \
	-search:OverlayString \
	-set:"$overlays" \
	-select:/ \
	-search:"Group/GroupName=HSK_LIBS/.." \
	-delete \
	-select:/ \
	-search:"Group/GroupName=HSK_LIBS::*/.." \
	-delete \
	-select:/ \
	-search:"Groups" \
	$libdeps \
	-select:/ \
	-print > uVision/hsk_dev.uvproj \
		&& rm uVision/hsk_dev.uvproj.bak \
		|| mv uVision/hsk_dev.uvproj.bak uVision/hsk_dev.uvproj

