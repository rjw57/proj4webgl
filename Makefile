PROJ_SRCS := $(wildcard proj/*)

COFFEE_SRCS := $(wildcard coffee/*.coffee)
COFFEE_JS := $(addprefix script/,$(notdir $(COFFEE_SRCS:.coffee=.js)))

HAML_SRCS := index.haml
HAML_HTML := $(HAML_SRCS:.haml=.html)

PYTHON3 := python3

all: $(HAML_HTML) $(COFFEE_JS) script/proj4gl-shaders.js

clean:
	rm -f proj4gl.js
	rm -f $(COFFEE_JS) $(HAML_HTML)

$(HAML_HTML) : %.html : %.haml
	haml $< $@

$(COFFEE_JS): script/%.js : coffee/%.coffee
	coffee -p $< >$@

script/proj4gl-shaders.js: Makefile $(PROJ_SRCS)
	echo '' >$@
	echo "define([], function() {" >>$@
	echo -n 'return ' >>$@
	$(PYTHON3) jsresource.py $(PROJ_SRCS) >>$@
	echo ';' >>$@
	echo '});' >>$@
