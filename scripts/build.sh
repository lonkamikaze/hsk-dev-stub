#!/bin/sh -f

IFS='
'

find -s "$@" -name \*.c | xargs awk -f scripts/includes.awk "$@"

all=
for SRC in "$@"; do
	SRC="${SRC%/}"
	# Collect dependencies for the build target
	files="$(find -s "$SRC" -name \*.c)"
	
	# Build instructions
	for file in $files; do
		target="\${BUILDDIR}/${file#$SRC/}"
		target="${target%.c}\${OBJSUFX}"
		echo "$target" | grep -qFx "$all" && continue
		all="${all:+$all$IFS}$target"
		echo "$target: $file
	@mkdir -p ${target%/*}
	\${CC} \${CFLAGS} -o $target -c $file
	"
	done

done

# Link instructions
files="$files${files:+$IFS}$(grep -lr '[^[:alnum:]]main[[:space:]]*(' "$@" | grep '\.c$')"

for file in $files; do
	target="$file"
	filter=
	for SRC in "$@"; do
		SRC="${SRC%/}"
		target="${target#$SRC/}"
		filter="$filter${filter:+$IFS}s:^$SRC:\${BUILDDIR}:"
	done
	target="\${BUILDDIR}/${target%.c}\${HEXSUFX}"
	echo "$target" | grep -qFx "$all" && continue
	all="${all:+$all$IFS}$target"
	linklist="$(awk -f scripts/includes.awk "$@" $file | cut -d: -f1 \
		| sed -ne "$filter" -e "s:\.c\$:\${OBJSUFX}:p" \
		| rs -TC\  )"

	echo "$target: $linklist
	@mkdir -p ${target%/*}
	\${CC} \${CFLAGS} -o $target $linklist
"
done

echo "build: $(echo $all)"

