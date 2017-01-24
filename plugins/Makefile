include ../Makefile.defs

SUBDIRS = regulus-docker regulus-cni

all: $(SUBDIRS)

$(SUBDIRS): force
	@ $(MAKE) -C $@ all

clean:
	for i in $(SUBDIRS); do $(MAKE) -C $$i clean; done

install:
	for i in $(SUBDIRS); do $(MAKE) -C $$i install; done

.PHONY: force
force :;
