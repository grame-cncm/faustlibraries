
LIBS := $(wildcard ../*.lib)

all: deps.pdf

help:
	@echo "============ Faust libraries tools ============"
	@echo "Available targets are:"
	@echo "  all (default) : compute a dependencies graph using dot"
	@echo "  clean         : remove output files"

deps.pdf: deps.dot

deps.dot: 
	echo "digraph impl { " > $@
	echo "margin=0.05;\n" >> $@
	egrep "=[ \t]*library|^import" $(LIBS) | sed -e 's/^\.\.\///' \
	| sed -e 's/:.*=[ \t]*library("/ -> /' | sed -e 's/:import("/ -> /' \
	| sed -e 's/"..*/;/' |sed -e 's/\.lib//g' | sed -e 's/\//_/g' >> $@
	echo "}" >> $@
	
clean:
	rm -f deps.pdf deps.dot

test:
	echo $(LIBS)

%.pdf: %.dot
	dot -Tpdf -o $@ $< 

