ROOT := $(abspath ../..)
LIB := -L$(ROOT)/cabi -lvelocitty -Wl,-rpath,$(ROOT)/cabi


demo: velocitty.c lib
	c++ -x c++ -I. velocitty.c $(LIB) -o demo

lib:
	cd $(ROOT) && dub build -q velocitty:cabi

.PHONY: lib