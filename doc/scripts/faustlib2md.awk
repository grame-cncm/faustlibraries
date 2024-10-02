
function removeComment (arg) {
	gsub(/^\/\//, "", arg);
	gsub(/^ /, "", arg);
	return arg;
}

function makeurl(arg) {
	if (index(arg, "<http")) {
		gsub(/ *[*-][^a-zA-Z0-9]/, "", arg);
		url = gensub(/[^>]*<(http[^>]+)>.*/, "\\1", 1, arg);
		if (url == arg) return arg;

		gsub(":", "://", url);			# for malformed url
		gsub(/\/\/\/\//, "//", url);	# to fix redundant //// 
		gsub(/<http..*>/, "["url"]("url")", arg);
		return "* "arg;
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
}

# scan headers (library name)
/^\/\/####*[^#]+/ {
	gsub(/\/\//, "", $0);
	gsub(/#*/, "", $0);
	print  makeheader($0);
	PRINTDOC = 1;
}

# scan function names
/^\/\/----*[^-]+/ {
	print makefunction($0);
	PRINTDOC = 1;
}

# documentation lines
/^\/\/ / {
	if (PRINTDOC) {
		line = removeComment($0);
		line = makeurl(line);
		print line;
	}
}

# preserve empty commented lines
/^\/\/$/ {
	if (PRINTDOC) print "";
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
