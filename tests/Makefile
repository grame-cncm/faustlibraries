DOC_INDEX_OUTPUT ?= faust-doc-index.json
DOC_INDEX_SPLIT_DIR ?= faust-doc

.PHONY: doc-index doc-index-split

doc-index:
	$(MAKE) -C .. doc-index DOC_INDEX_OUTPUT=tests/$(DOC_INDEX_OUTPUT)

doc-index-split:
	$(MAKE) -C .. doc-index-split DOC_INDEX_OUTPUT=tests/$(DOC_INDEX_OUTPUT) DOC_INDEX_SPLIT_DIR=tests/$(DOC_INDEX_SPLIT_DIR)
