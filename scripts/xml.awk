#!/usr/bin/awk -f

BEGIN {
	FS = ""
	RS = ""
	SUBSEP = ","
	INDENT = "  "
	ROOT = "-1,-1"
	depth = 0
	count[-1] =  0
	count[0] = 0
	selection[ROOT] = 1
}

function explode(str, results,
i, array, quoted, count) {
	split(str, array)
	str = ""
	for (i = 1; i <= length(array); i++) {
		if (array[i] == "\"") {
			quoted = !quoted
			continue
		}

		if (!quoted && array[i] ~ /[[:space:]]/) {
			if (length(str)) {
				results[count++] = str
				str = ""
			}
			continue
		}

		if (array[i] == "\\") {
			i++
		}

		str = str array[i]
	}
	if (length(str)) {
		results[count++] = str
	}
	return count
}

function escape(str) {
	gsub(/\\/, "\\\\", str)
	gsub(/"/, "\\\"", str)
	return str
}

#
# This function lets you define a selection filter.
#
function cmdSelect(str,
ident, node, ns, i, attrib, value) {
	gsub(/\/+/, "/", str)

	while (length(str)) {
		ident = str
		sub(/\/.*/, "/", ident)
		sub(/[^\/]*\/?/, "", str)

		# Select /
		if (ident == "/") {
			for (node in selection) {
				delete selection[node]
			}
			selection[ROOT] = 1
		}
		# Select ./
		else if (ident ~ /^\.\/?$/) {
			# Nothing to do here
		}
		# Select ../
		else if (ident ~ /^\.\.\/?$/) {
			for (node in ns) {
				delete ns[node]
			}
			for (node in selection) {
				delete selection[node]
				ns[parent[node]]
			}
			for (node in ns) {
				selection[node] = 1
			}
		}
		# Select tags
		else {
			sub(/\/$/, "", ident)
			gsub(/\./, "\\.", ident)
			gsub(/\*/, ".*", ident)
			gsub(/\?/, ".", ident)

			attrib = ident
			sub(/[\[=].*/, "", ident)
			for (node in ns) {
				delete ns[node]
			}
			for (node in selection) {
				delete selection[node]
				for (i = 0; children[node, i]; i++) {
					if (tagNames[children[node, i]] ~ "^" ident "$") {
						ns[children[node, i]]
					}
				}
			}
			for (node in ns) {
				selection[node] = 1
			}

			# Recover ident
			ident = attrib

			# Select tags with an attribute
			while (ident ~ /\[[[:alnum:]]*=.*\]/) {
				attrib = ident
				value = attrib
				sub(/[^\[]*\[/, "", attrib)
				sub(/=.*/, "", attrib)
				sub(/[^=]*=/, "", value)
				sub(/\].*/, "", value)
				sub(/[^\]]*\]/, "", ident)

				for (node in selection) {
					delete selection[node]
					for (i = 0; attributeNames[node, i]; i++) {
						if ((attributeNames[node, i] ~ "^" attrib "$") && (attributeValues[node, i] ~ "^" value "$")) {
							selection[node] = 1
						}
					}
				}
			}

			# Select tags with a given value
			sub(/[^=]*/, "", ident)
			if (ident ~ /^=/) {
				sub(/^=/, "", ident)
				
				for (node in selection) {
					if (contents[node] !~ "^" ident "$") {
						delete selection[node]
					}
				}
			}
		}
	}
	
}

function cmdSearch(str,
node, i, lastSelection, matches) {
	while (length(selection) > 0) {
		for (node in selection) {
			lastSelection[node]
		}

		cmdSelect(str)

		for (node in selection) {
			matches[node]
			delete selection[node]
		}

		for (node in lastSelection) {
			for (i = 0; children[node, i]; i++) {
				selection[children[node, i]] = 1
			}
			delete lastSelection[node]
		}
	}
	for (node in matches) {
		selection[node] = 1
	}
}

function cmdPrint(,
node) {
	for (node in selection) {
		printNode(0, node)
		print
	}
}

function printNode(indent, node,
prefix, i, p) {
	for (i = 0; i < indent; i++) {
		prefix = INDENT prefix
	}
	for (i = 0; children[node, i]; i++) {
		printf "%s<%s", prefix, tagNames[children[node, i]]
		for (p = 0; attributeNames[children[node, i], p]; p++) {
			printf " %s=\"%s\"", attributeNames[children[node, i], p], escape(attributeValues[children[node, i], p])
		}
		if (children[children[node, i], 0]) {
			printf ">\n"
			printNode(indent + 1, children[node, i])
			printf "%s</%s>\n", prefix, tagNames[children[node, i]]
		} else if (contents[children[node, i]]) {
			printf ">%s</%s>\n", contents[children[node, i]], tagNames[children[node, i]]
		} else if (tagNames[children[node, i]] ~ /^\?/) {
			printf " ?>\n"
		} else {
			printf " />\n"
		}
	}
	printf "%s", contents[node]
}

# Parse the XML tree
#
# Properties:
# tags [d, c]
# tagNames [d, c]
# tagValues [d, c]
# attributes [d, c, name]: value
# attributeNames [d, c, i]
# attributeValues [d, c, i]
# children [d, c, i]
# parent [d, c]
{
	while (/<.*>/) {
		# Get the current content
		content = $0
		sub(/[[:space:]]*<.*/, "", content)
		
		# Get the next tag
		sub(/[^<]*</, "")
		tag = $0
		sub(/>.*/, "", tag)
		sub(/[^>]*>/, "")

		# This is a closing tag
		if (tag ~ /^\//) {
			depth--
			sub(/^[[:space:]]*/, "", content)
			sub(/[[:space:]]*$/, "", content)
			contents[depth, count[depth] - 1] = content
		}

		# This is an opening tag
		else {
			# Register with the parent
			current = depth SUBSEP count[depth]
			parent[current] = (depth - 1) SUBSEP (count[depth - 1] - 1)
			for (i = 0; children[parent[current], i]; i++);
			children[parent[current], i] = depth SUBSEP count[depth]

			# Raw tag
			tags[current] = tag
			tagName = tag

			# Name of the tag
			sub(/[[:space:]].*/, "", tagName)
			tagNames[current] = tagName

			# Get attributes
			tagAttributes = tag
			sub(/[^[:space:]]*[[:space:]]*/, "", tagAttributes)
			sub(/(\/|\?)$/, "", tagAttributes)
			countAttributes = explode(tagAttributes, tagAttributesArray)
			for (i = 0; i < countAttributes; i++) {
				attributeName = tagAttributesArray[i]
				sub(/=.*/, "", attributeName)
				attributeValue = tagAttributesArray[i]
				sub(/[^=]*=/, "", attributeValue)
				attributes[current, attributeName] = attributeValue
				attributeNames[current, i] = attributeName
				attributeValues[current, i] = attributeValue
			}

			count[depth]++
			# This is not a self-closing tag
			if (tag !~ /^\?.*\?$/ && tag !~ /\/$/) {
				depth++
				count[depth] += 0
			}
		}
	}
}

END {
	cmdSearch("Groups")
	cmdPrint()
}

