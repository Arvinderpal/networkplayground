include ../Makefile.defs

CLANG_FLAGS := -Iinclude -D__NR_CPUS__=$(shell nproc) -O2 -target bpf -I. -Wall -Werror

BPF = bpf_g3.o 
# bpf_netdev.o bpf_overlay.o bpf_lb.o
SCRIPTS = init.sh 
# join_ep.sh leave_ep.sh run_probes.sh
LIB := $(shell find ./lib -name '*.h')

ifeq ("$(PKG_BUILD)","")

all: $(BPF)
	$(MAKE) -C go

bpf_g3.o:
	clang ${CLANG_FLAGS} -c bpf_g3.c -o $@

install: install-common
	$(MAKE) -C go install

else
# if we want to install regulus on the system, try this:
all:

install: install-common

endif

install-common:
	$(INSTALL) -m 0644 -t $(DESTDIR)$(LIBDIR)/regulus/ $(BPF:.o=.c)
	$(INSTALL) -m 0755 -t $(DESTDIR)$(LIBDIR)/regulus/ $(SCRIPTS)
	$(INSTALL) -m 0644 -t $(DESTDIR)$(LIBDIR)/regulus/lib/ $(LIB)
	for dir in `find include probes -type d`; do \
		$(INSTALL) -m 0755 -d $(DESTDIR)$(LIBDIR)/regulus/$$dir; \
		for f in `find $$dir -maxdepth 1 -type f`; do \
			$(INSTALL) -m 0644 -t $(DESTDIR)$(LIBDIR)/regulus/$$dir $$f; \
		done; \
	done

clean:
	rm -fr *.o
	$(MAKE) -C go clean
