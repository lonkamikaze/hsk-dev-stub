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
-insert:FilePath=../$lib
-select:.."
	incpaths="$incpaths${incpaths:+;}../${lib%/*}"
	incfiles="$incfiles${IFS}$lib"
done

overlays="$(awk '
BEGIN {RS = ";"}

{
	gsub(/\/\*[^*]*([^*]*\*[^\/])*\*\//, "")
	gsub(/[[:space:][:cntrl:]]+/, "")
	gsub(/^[{}]*/, "")
	gsub(/[{}]*$/, "")
}

/^hsk_isr[0-9]+\.[[:alnum:]]+=&[[:alnum:]_]+$/ {
	sub(/^/, "ISR_")
	sub(/\..*=&/, " ! ")
	overlays[$0]
}

/^hsk_timer[0-9]+_setup\(.*,&[[:alnum:]_]+\)$/ {
	sub(/^/, "ISR_")
	sub(/_setup\(.*,&/, " ! ")
	sub(/\)$/, "")
	overlays[$0]
}

END {
	for (overlay in overlays) {
		if (count++) {
			printf ",\r\n"
		}
		printf "%s", overlay
	}
}
' $incfiles $(find src/ -name \*.c))"

cp uVision/hsk_dev.uvproj uVision/hsk_dev.uvproj.bak
awk -f scripts/xml.awk uVision/hsk_dev.uvproj.bak \
	-search:TargetName \
	-set:"$PROJECT" \
	-select:/ \
	-search:OutputName \
	-set:"$project" \
	-select:/ \
	-search:IncludePath \
	-set:"../$LIBDIR" \
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

