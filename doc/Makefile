
MAKE 	?= make
AWK		?= gawk

DOCDIR   := docs
SITEDIR	 := ../docs
FAUSTLIBS ?= ../../faustlibraries

SRC   	 := $(shell cat ../../faustlibraries/all.lib | grep import | sed -e 's/[^"]*"\(..*\.lib\).*/\1/')
MD   	 := $(SRC:%.lib=$(DOCDIR)/libs/%.md)
LIST   	 := $(SRC:%.lib=%)

####################################################################
help:
	@echo "========================================================================"
	@echo "                     Faust Libraries Documentation"
	@echo "This Makefile is intended to generate the faust libraries documentation"
	@echo "========================================================================"
	@echo "Available targets are:"
	@echo "  install  : install the required components"
	@echo "  build    : build the web site"
	@echo "  serve    : launch the mkdoc server"
	@echo "Development specific targets are available:"
	@echo "  md       : build the md files"
	@echo "  index    : build the index file"
	@echo "  clean    : removes the output of the md target"
	@echo "  list     : list libraries (ready to be included in mkdocs.yml menu)"

test: 
	@echo MD: $(MD)

####################################################################
build:
	$(MAKE) md
	$(MAKE) index
	mkdocs build
	git checkout $(SITEDIR)/CNAME

serve:
	@echo "you can browse the site at http://localhost:8000"
	mkdocs serve

list:
	@echo $(foreach e, $(LIST), "        - '" $e "':  libs/"$e.md"\n")
	
pdf:
	pandoc --toc docs/index.md docs/organization.md docs/standardFunctions.md docs/contributing.md docs/about.md docs/libs/*.md -o library.pdf

clean:
	rm -f $(MD)
	

####################################################################
# building md files
md : $(DOCDIR)/libs $(MD)

$(DOCDIR)/libs :
	mkdir $(DOCDIR)/libs 

$(DOCDIR)/libs/%.md:$(FAUSTLIBS)/%.lib 
	@echo ========= building $<
	cat $< | $(AWK) -f scripts/faustlib2md.awk > $@

####################################################################
# building index
index: $(DOCDIR)/libs/index.md
$(DOCDIR)/libs/index.md : $(MD)
	$(AWK) -f scripts/makeindex.awk $(MD) > $@
	

####################################################################
$(FAUSTDIR):
	@echo "FAUSTLIBS not found ! ($(FAUSTLIBS))"
	@echo "you should either:"
	@echo "   - set FAUSTLIBS to the faust projet location in this Makefile"
	@echo "   - call $(MAKE) FAUSTLIBS=faust_projet_path"
	@false;

####################################################################
install:
	pip install mkdocs
	pip install mkdocs-pdf-export-plugin
	pip install markdown-include
	pip install mkdocs-bootswatch
	pip install python-markdown-math

uninstall:
	pip uninstall -y mkdocs-material
	pip uninstall -y pymdown-extensions
	pip uninstall -y markdown-blockdiag
	pip uninstall -y mkdocs-pdf-export-plugin
