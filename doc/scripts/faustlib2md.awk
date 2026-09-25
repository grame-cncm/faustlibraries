
function removeComment (arg) {
	gsub(/^\/\//, "", arg);
	gsub(/^ /, "", arg);
	return arg;
}

# A line with a <http...> URL becomes a list item only when it is one: it
# starts with a "* " or "- " marker, or it holds nothing but the URL and
# starts or continues a list (after an empty line, a heading or an item).
# Elsewhere, e.g. a URL ending a sentence or continuing an item on its next
# line, only the URL is turned into a link: a "* " there would print a
# literal asterisk in the middle of a paragraph.
function makeurl(arg, prev,   item) {
	if (index(arg, "<http")) {
		item = (arg ~ /^[*-] /) || \
			(arg ~ /^<http[^>]*>[.,;)]*$/ && (prev == "" || prev ~ /^#/ || prev ~ /^\* /));
		sub(/^[*-] +/, "", arg);
		url = gensub(/[^>]*<(http[^>]+)>.*/, "\\1", 1, arg);
		if (url == arg) return arg;

		# Complete a malformed "http:host" only: a global substitution also
		# broke the other colons of a URL (e.g. a "#:~:text=" fragment).
		if (url !~ /^https?:\/\//) sub(/:\/*/, "://", url);
		gsub(/<http..*>/, "["url"]("url")", arg);
		return item ? "* "arg : arg;
	}
	return arg;
}

function makefunction (arg) {
	gsub(/\/\//, "", arg);
	gsub(/-*/, "", arg);
	return "\n----\n\n### " arg "\n";
}

function makegroup (arg) {
	gsub(/\/\//, "", arg);
	gsub(/=*/, "", arg);
	return "\n## " arg "\n";
}

function makeheader (libname) {
	return "# "libname "\n";
}

BEGIN {
	STARTF = 0;		# used to start functions analysis
	PRINTDOC = 0;
	INGROUP = 0;
	NAME = "";
	VERSION = "";
}

END {
}

/^\/\/====*$/ { }
/^\/\/####*$/ { PRINTDOC = 0; }	# end documentation lines
/^\/\/====*$/ { PRINTDOC = 0; }	# end function documentation
/^\/\/----*$/ { PRINTDOC = 0; }	# end function documentation
/^\/\/ end/   { }

# scan group names)
/^\/\/====*[^=]+/ {
	print makegroup($0);
	PRINTDOC = 1;
	PREV = "";
}

# scan headers (library name)
/^\/\/####*[^#]+/ {
	gsub(/\/\//, "", $0);
	gsub(/#*/, "", $0);
	print  makeheader($0);
	PRINTDOC = 1;
	PREV = "";
}

# scan function names
/^\/\/----*[^-]+/ {
	print makefunction($0);
	PRINTDOC = 1;
	PREV = "";
}

# documentation lines
/^\/\/ / {
	if (PRINTDOC) {
		line = removeComment($0);
		line = makeurl(line, PREV);
		print line;
		PREV = line;
	}
}

# preserve empty commented lines
/^\/\/$/ {
	if (PRINTDOC) { print ""; PREV = ""; }
}

# is the following really supported (?)
/declare name[ 	]*]/ {
	gsub(/^[^"]*"/, "", $0);
	gsub(/".*/, "", $0);
	NAME = $0;
}

/declare version[ 	]*]/ {
	gsub(/^[^"]*"/, "", $0);
	gsub(/".*/, "", $0);
	VERSION = $0;
}
