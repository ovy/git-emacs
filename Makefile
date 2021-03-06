# Simple makefile. We make no particular effort to optimize dependencies,
# since compiling all files in a run is very fast anyway.

# Careful not to put your own "production" version in -L, nullifying the tests.
EMACS_BATCH=emacs -Q --batch -L . -f toggle-debug-on-error

.PHONY: all compile tags test clean

all: compile tags test

compile: *.el
	@echo; echo ">>> Compiling"
	rm -f *.elc
	$(EMACS_BATCH) -f batch-byte-compile *.el

tags: *.el
	@echo; echo ">>> Updating tags"
	etags *.el

test: *.el
	@echo; echo ">>> Running tests"
	@echo "[Ignore warnings about flet being obsolete until we get a decent replacement. Really. Just ignore them. Maybe silent disapproval will get the point through]"
	$(EMACS_BATCH) -l git--test.el -f git-regression
	@echo; echo "Testing autoloads..."
# 	Don't ask about the (point). It's a weirdness with EmacsMac --eval, I
# 	get "end of file during parsing" if the first sexpr has quotes. Ugh.
	$(EMACS_BATCH) --eval "(point) (require 'git-emacs-autoloads)" \
	  --visit "Makefile" \
	  --eval "(point) (unless (functionp 'git-diff-upstream) (error \"autoload malfunctioned\"))"

clean:
	rm -f *.elc
