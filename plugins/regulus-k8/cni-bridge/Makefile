include ../../../Makefile.defs

all: cni-bridge

TARGET=cni-bridge

clean:
	go clean
	rm -f $(TARGET)

SOURCES := $(shell find . -name '*.go')

$(TARGET): $(SOURCES)
	go build -o $(TARGET) 

install:
	$(INSTALL) -m 0755 -d $(DESTDIR)/etc/cni/net.d
	$(INSTALL) -m 0644 cni-bridge.conf $(DESTDIR)/etc/cni/net.d
	$(INSTALL) -m 0755 -d $(DESTDIR)/opt/cni/bin
	$(INSTALL) -m 0755 $(TARGET) $(DESTDIR)/opt/cni/bin
