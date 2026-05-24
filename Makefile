.PHONY: build install uninstall clean

PREFIX  ?= /usr/local
BINDIR   = $(PREFIX)/bin
LIBEXEC  = $(PREFIX)/libexec

build:
	cd helper && swift build -c release
	cd cli    && odin build . -out:strudel -o:speed

install: build
	@if [ "`id -u`" = "0" ]; then SUDO=""; else SUDO="sudo"; fi; \
	$$SUDO install -d $(BINDIR) $(LIBEXEC); \
	$$SUDO install -m 0755 cli/strudel                                  $(BINDIR)/strudel; \
	$$SUDO install -m 0755 helper/.build/release/strudel-helper         $(LIBEXEC)/strudel-helper
	@echo "strudel installed."

uninstall:
	@if [ "`id -u`" = "0" ]; then SUDO=""; else SUDO="sudo"; fi; \
	$$SUDO rm -f $(BINDIR)/strudel $(LIBEXEC)/strudel-helper
	@echo "strudel removed."

clean:
	rm -rf helper/.build
	rm -f  cli/strudel
