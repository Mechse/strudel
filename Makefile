.PHONY: build install uninstall clean

PREFIX  ?= /usr/local
BINDIR   = $(PREFIX)/bin
LIBEXEC  = $(PREFIX)/libexec

build:
	cd helper && swift build -c release
	cd cli    && odin build . -out:saft -o:speed

install: build
	@if [ "`id -u`" = "0" ]; then SUDO=""; else SUDO="sudo"; fi; \
	$$SUDO install -d $(BINDIR) $(LIBEXEC); \
	$$SUDO install -m 0755 cli/saft                                  $(BINDIR)/saft; \
	$$SUDO install -m 0755 helper/.build/release/saft-helper         $(LIBEXEC)/saft-helper
	@echo "saft installed."

uninstall:
	@if [ "`id -u`" = "0" ]; then SUDO=""; else SUDO="sudo"; fi; \
	$$SUDO rm -f $(BINDIR)/saft $(LIBEXEC)/saft-helper
	@echo "saft removed."

clean:
	rm -rf helper/.build
	rm -f  cli/saft
