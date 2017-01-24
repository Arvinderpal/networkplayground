include ../../Makefile.defs

TARGET=regulus-docker

all: $(TARGET)

SOURCES := $(shell find . -name '*.go')

$(TARGET): $(SOURCES)
	go build -ldflags "-X "github.com/networkplayground/common".Version=$(VERSION)" -o $(TARGET)

run:
	./regulus-docker -d

clean:
	go clean
	rm -f $(TARGET)

install: all
	$(INSTALL) -m 0755 $(TARGET) $(DESTDIR)$(BINDIR)
