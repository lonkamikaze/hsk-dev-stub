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

replace="
TargetName:$PROJECT
OutputName:$project
IncludePath:../$LIBDIR
"

replace="$(echo "$replace" | sed -E 's/([^:]*):(.*)/s:(<\1([[:space:]][^>]*)?>)[^<]*(<\/\1>):\\1\2\\3:g/')"

sed -i.bak -E "$replace"  uVision/hsk_dev.uvproj && rm uVision/hsk_dev.uvproj.bak

