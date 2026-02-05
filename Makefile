CC = gcc
CFLAGS = -Wall -Wextra -O2 $(shell pkg-config --cflags gtk+-3.0 vte-2.91)
LDFLAGS = $(shell pkg-config --libs gtk+-3.0 vte-2.91)

# Targets
TARGET = svte
SRC = svte.c

# Debug flags
CFLAGS_DEBUG = -Wall -Wextra -g -DDEBUG $(shell pkg-config --cflags gtk+-3.0 vte-2.91)

# Installation directories
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
DATADIR = $(PREFIX)/share
APPLICATIONSDIR = $(DATADIR)/applications
PIXMAPSDIR = $(DATADIR)/pixmaps

.PHONY: all clean install uninstall debug check test help

# Default target
all: $(TARGET)

# Build the terminal
$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)
	@echo "✓ Built: $(TARGET)"

# Debug build
debug: $(SRC)
	$(CC) $(CFLAGS_DEBUG) -o $(TARGET) $(SRC) $(LDFLAGS)
	@echo "✓ Built debug version"

# Check dependencies
check:
	@echo "Checking for required dependencies..."
	@pkg-config --exists gtk+-3.0 || (echo "ERROR: gtk+-3.0 not found" && exit 1)
	@pkg-config --exists vte-2.91 || (echo "ERROR: vte-2.91 not found" && exit 1)
	@echo "✓ All dependencies found"
	@echo ""
	@echo "GTK+ version: $$(pkg-config --modversion gtk+-3.0)"
	@echo "VTE version: $$(pkg-config --modversion vte-2.91)"

# Run tests
test: $(TARGET)
	@./$(TARGET) --test

# Clean build artifacts
clean:
	rm -f $(TARGET)
	@echo "✓ Cleaned build artifacts"

# Install
install: $(TARGET)
	@echo "Installing SVTE Terminal..."
	install -Dm755 $(TARGET) $(DESTDIR)$(BINDIR)/$(TARGET)
	install -Dm644 svte.desktop $(DESTDIR)$(APPLICATIONSDIR)/svte.desktop
	@if [ -f svte.svg ]; then \
		install -Dm644 svte.svg $(DESTDIR)$(PIXMAPSDIR)/svte.svg; \
	fi
	@if command -v update-desktop-database >/dev/null 2>&1; then \
		update-desktop-database $(DESTDIR)$(APPLICATIONSDIR) || true; \
	fi
	@echo "✓ Installed to $(BINDIR)/$(TARGET)"

# Uninstall
uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(TARGET)
	rm -f $(DESTDIR)$(APPLICATIONSDIR)/svte.desktop
	rm -f $(DESTDIR)$(PIXMAPSDIR)/svte.svg
	@if command -v update-desktop-database >/dev/null 2>&1; then \
		update-desktop-database $(DESTDIR)$(APPLICATIONSDIR) || true; \
	fi
	@echo "✓ Uninstalled SVTE"

# Help
help:
	@echo "SVTE Terminal Makefile targets:"
	@echo ""
	@echo "  make              Build the terminal"
	@echo "  make debug        Build with debug symbols"
	@echo "  make check        Verify dependencies"
	@echo "  make test         Run test suite"
	@echo "  make install      Install to $(PREFIX)"
	@echo "  make uninstall    Remove installed files"
	@echo "  make clean        Remove build artifacts"
	@echo "  make help         Show this help"
	@echo ""
	@echo "Features:"
	@echo "  • Multi-tab support"
	@echo "  • Sixel image support"
	@echo "  • Gruvbox color scheme"
	@echo "  • 10,000 line scrollback"
