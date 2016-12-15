include ../Makefile.defs

TARGET=regulus

all: $(TARGET)

run:
	./regulus

clean:
	go clean
	rm -f $(TARGET)

SOURCES := $(shell find ../bpf ../daemon ../common ../pkg . -name '*.go')

$(TARGET): $(SOURCES)
	go build -ldflags "-X "github.com/networkplayground/common".Version=$(VERSION)" -o $(TARGET) ./main.go

# install: all
# 	$(INSTALL) -m 0755 $(TARGET) $(DESTDIR)$(BINDIR)
# 	$(INSTALL) -m 0755 -d $(DESTDIR)$(CONFDIR)/bash_completion.d
# 	$(INSTALL) -m 0644 -T ../contrib/autocomplete/bash_autocomplete $(DESTDIR)$(CONFDIR)/bash_completion.d/cilium
