
MAKE 	?= make
AWK		?= awk

DOCDIR   := docs
FAUSTLIBS ?= ../../faustlibraries

SRC   	 := $(shell cat ../../faustlibraries/all.lib | grep import | sed -e 's/[^"]*"\(..*\.lib\).*/\1/')
MD   	 := $(SRC:%.lib=$(DOCDIR)/libs/%.md) $(DOCDIR)/index.md
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
	@echo "  all      : generates all the necessary files from the src folder"
	@echo "             actually call the 'md', 'options', 'tools', 'svg' and 'examples' targets"
	@echo "Development specific targets are available:"
	@echo "  md       : build the md files"
	@echo "  list     : list libraries"
	@echo "Making the current version publicly available:"
	@echo "  publish  : make all + build, switch to gh-pages and copy to root"
	@echo "             commit and push are still manual operations"

test: 
	@echo MD: $(MD)

####################################################################
build:
	mkdocs build

serve:
	@echo "you can browse the site at http://localhost:8000"
	mkdocs serve

all:
	$(MAKE) md

list:
	@echo $(foreach e, $(LIST), "        - '" $e "':  libs/"$e.md"\n")

clean:
	rm -f $(MD)
	

####################################################################
# building md files
md : $(DOCDIR)/libs $(MD)

$(DOCDIR)/libs :
	mkdir $(DOCDIR)/libs 

$(DOCDIR)/index.md: ../README.md
	cat $< > $@

$(DOCDIR)/libs/%.md:$(FAUSTLIBS)/%.lib 
	@echo ========= building $<
	cat $< | $(AWK) -f scripts/faustlib2md.awk > $@

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

uninstall:
	pip uninstall -y mkdocs-material
	pip uninstall -y pymdown-extensions
	pip uninstall -y markdown-blockdiag
	pip uninstall -y mkdocs-pdf-export-plugin
