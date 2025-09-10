
function makeSection(file) {
	section = file;
	gsub(/^docs\/libs\//, "", section);   # keep subpath under docs/libs/
	sub(/\.md$/, "", section);
	return section;
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
	print "# Faust Libraries Index\n\n--------\n";
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
	print "[" fun "](" SECTION ".md#" tolower(link) ") &nbsp; &nbsp;";
}
