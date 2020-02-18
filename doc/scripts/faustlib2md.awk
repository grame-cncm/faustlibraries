
function removeComment (arg) {
	gsub(/\/\//, "", arg);
	gsub(/^ /, "", arg);
	return arg;
}

function makeurl(arg) {
	if (index(arg, "<http")) {
		gsub(/ *[*-]/, "", arg);
		url = gensub(/[^>]*<(http[^>]+)>.*/, "\\1", 1, arg);
		if (url == arg) return arg;

		gsub(":", "://", url);
		gsub(/<http..*>/, "["url"]("url")", arg);
		return "* "arg;
	}
	return arg;
}

function makefunction (arg) {
	gsub(/\/\//, "", arg);
	gsub(/-*/, "", arg);
	return "\n----\n### " arg;
}

function makegroup (arg) {
	gsub(/\/\//, "", arg);
	gsub(/=*/, "", arg);
	return "\n## " arg;
}

function makeheader () {
	return "# "LIBNAME "\n" SHORTDESC;
}

BEGIN {
	STARTF = 0;
	INFUN = 0;
	HEADER = "";
	NAME = "";
	VERSION = "";
	LIBNAME = "";
	SHORTDESC = "";	
}

END {
}



/^\/\/====*$/ { }
/^\/\/####*$/ { }
/^\/\/----*$/ { INFUN = 0; }
/^\/\/ end/   { }

# scan group names)
/^\/\/====*[^=]+/ {
	if (STARTF == 0)
		print  makeheader();
	STARTF = 1;
	print makegroup($0);
}

# scan header (library name)
/^\/\/####*[^#]+/ {
	gsub(/\/\//, "", $0);
	gsub(/#*/, "", $0);
	LIBNAME = $0;
}

# scan function names
/^\/\/----*[^-]+/ {
	if (STARTF == 0)
		print  makeheader();
	STARTF = 1;
	INFUN = 1;
	print makefunction($0);
}

# documentation lines
/^\/\/ / {
	line = removeComment($0);
	line = makeurl(line);
	if (length(SHORTDESC) == 0)
		SHORTDESC = line;
	if (STARTF && INFUN) print line;
}

# preserve empty commented lines
/^\/\/$/ {
	print "";
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
