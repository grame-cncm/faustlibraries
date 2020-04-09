
function makeSection(file) {
	sub(".*/", "", file)
	sub(".md", "", file);
	return file;
}

function printSection() {
	print "### " SECTION;
	print OUT "\n";
	OUT = "";
}

BEGIN {
	OUT = "";
	SECTION = "";
	PREVSECTION = "";
}

END {
}


# scan function names
/^### `\(/ {
	SECTION = makeSection(FILENAME);
	if (SECTION != PREVSECTION) {		# scan file change
		print "\n## " SECTION "\n";
		PREVSECTION = SECTION;
	}
	gsub(/### `/, "", $0);
	fun = $0;
	gsub(/`/, "", fun);
	link = fun;
	gsub(/[\[\]\|\(\)\.]/, "", link); 	# remove () [] | and .
	gsub(" ", "-", link);   				# replace space with -
	print "[" fun "](" SECTION "/#" tolower(link) ") ";
}
