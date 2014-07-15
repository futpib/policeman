
coffee_modules = $(shell find extension/lib    -type f -name '*.coffee')
coffee_scripts = $(shell find extension -type f -not -path '*/lib/*' -not -path '*/macros/*' -name '*.coffee')
jison_files = $(shell find extension -type f -name '*.jison')

svg_files = $(shell find extension/chrome/skin -type f -name '*.svg')
icon = "extension/icon.svg"

js_files = $(coffee_modules:.coffee=.jsm)
js_files += $(coffee_scripts:.coffee=.js)
js_files += $(jison_files:.jison=.js)

all: clean gen
	@echo "Done all"

gen: coffee jison

coffee:
	@echo "Compiling coffee to js..."

	@for f in $(coffee_scripts); do \
		coffee -cbp $$f > $${f/%.coffee/.js} \
			|| exit; \
	done;
	@for f in $(coffee_modules); do \
		coffee -cbp $$f > $${f/%.coffee/.jsm} \
			|| exit; \
	done;

jison:
	@echo "Compiling jison to js..."
	@for f in $(jison_files); do jison -o $${f/%.jison/.jsm} $${f}; done

svg:
	@echo "Rasterizing svg icons..."
	@for f in $(svg_files); do \
		inkscape -z -e $${f/%.svg/-16.png} -w 16 -h 16 $${f} >/dev/null;\
		inkscape -z -e $${f/%.svg/-32.png} -w 32 -h 34 $${f} >/dev/null;\
		inkscape -z -e $${f/%.svg/-64.png} -w 64 -h 64 $${f} >/dev/null;\
	done;
	@for f in $(icon); do \
		inkscape -z -e $${f/%.svg/.png} -w 64 -h 64 $${f} >/dev/null;\
	done;

clean:
	@echo "Performing clean..."
	@rm -f $(js_files)
