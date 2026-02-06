#!/bin/bash
# SVTE Terminal Emulator - Setup Script (Fixed Version)
# Purpose: Build, test, and prepare SVTE for installation
# Features: Better error handling, source checking, comprehensive testing

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/svte-setup-$(date +%Y%m%d-%H%M%S).log"
VERBOSE=false
DEV_MODE=false
BUILD_TYPE="release"
TEST_ONLY=false

# Color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if [ "$VERBOSE" = true ] || [ "$level" != "DEBUG" ]; then
        case "$level" in
            ERROR) echo -e "${RED}✗ $message${NC}" ;;
            WARN)  echo -e "${YELLOW}⚠ $message${NC}" ;;
            INFO)  echo -e "${BLUE}ℹ $message${NC}" ;;
            SUCCESS) echo -e "${GREEN}✓ $message${NC}" ;;
            DEBUG) [ "$VERBOSE" = true ] && echo -e "${CYAN}→ $message${NC}" ;;
        esac
    fi
}

handle_error() {
    local exit_code=$1
    local line_number=$2
    log ERROR "Setup failed at line $line_number with exit code $exit_code"
    echo -e "\n${RED}${BOLD}Setup failed!${NC}"
    echo -e "Log file: ${BLUE}$LOG_FILE${NC}\n"
    exit "$exit_code"
}

trap 'handle_error $? $LINENO' ERR

check_command() {
    command -v "$1" &> /dev/null
}

# ============================================================================
# HEADER
# ============================================================================

print_header() {
    clear
    echo -e "${BOLD}${CYAN}SVTE Terminal Emulator - Setup Script${NC}\n"
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

check_source_files() {
    log INFO "Checking for required source files..."
    
    if [ ! -f "$SCRIPT_DIR/svte.c" ]; then
        echo -e "${RED}${BOLD}ERROR: svte.c not found!${NC}\n"
        echo -e "${YELLOW}This setup script requires the SVTE source code.${NC}"
        echo -e "${CYAN}Expected location: ${BOLD}$SCRIPT_DIR/svte.c${NC}\n"
        echo -e "${YELLOW}Solutions:${NC}"
        echo -e "1. If you have the source elsewhere:"
        echo -e "   ${BLUE}cp /path/to/svte.c $SCRIPT_DIR/${NC}"
        echo -e "2. If you need to download the source:"
        echo -e "   ${BLUE}git clone <repository-url> && cd svte${NC}"
        echo -e "3. If you only have a compiled binary, use install.sh instead"
        echo ""
        log ERROR "svte.c not found in $SCRIPT_DIR"
        exit 1
    fi
    
    log SUCCESS "Source file found: svte.c"
    echo -e "${GREEN}✓ Source file verified${NC}\n"
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=$ID
        DISTRO_VERSION=${VERSION_ID:-unknown}
        DISTRO_NAME=$NAME
        log INFO "Detected: $DISTRO_NAME ($DISTRO_ID $DISTRO_VERSION)"
    else
        log ERROR "Cannot detect distribution"
        exit 1
    fi
    
    echo -e "${BLUE}Distribution:${NC} $DISTRO_NAME"
    echo -e "${BLUE}Version:${NC} $DISTRO_VERSION"
    
    # Detect desktop environment
    if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
        echo -e "${BLUE}Desktop:${NC} $XDG_CURRENT_DESKTOP"
    fi
    
    # Detect display server
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        echo -e "${BLUE}Display Server:${NC} Wayland"
    elif [ -n "${DISPLAY:-}" ]; then
        echo -e "${BLUE}Display Server:${NC} X11"
    fi
    echo ""
}

check_dependencies() {
    log INFO "Checking build dependencies..."
    local missing_deps=()
    
    # Build tools
    for tool in gcc make pkg-config; do
        if ! check_command "$tool"; then
            missing_deps+=("$tool")
        fi
    done
    
    # Libraries
    if ! pkg-config --exists gtk+-3.0 2>/dev/null; then
        missing_deps+=("gtk+-3.0")
    else
        local gtk_ver=$(pkg-config --modversion gtk+-3.0)
        echo -e "${GREEN}  ✓ GTK+ ${NC}$gtk_ver"
    fi
    
    if ! pkg-config --exists vte-2.91 2>/dev/null; then
        missing_deps+=("vte-2.91")
    else
        local vte_ver=$(pkg-config --modversion vte-2.91)
        echo -e "${GREEN}  ✓ VTE ${NC}$vte_ver"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log WARN "Missing dependencies: ${missing_deps[*]}"
        echo -e "\n${YELLOW}Missing dependencies:${NC}"
        printf '  • %s\n' "${missing_deps[@]}"
        return 1
    else
        log SUCCESS "All dependencies found"
        return 0
    fi
}

install_dependencies() {
    log INFO "Installing dependencies for $DISTRO_ID..."
    echo -e "\n${BOLD}Installing dependencies...${NC}\n"
    
    case $DISTRO_ID in
        arch|manjaro|endeavouros|artix|garuda)
            sudo pacman -Sy --needed --noconfirm gtk3 vte3 base-devel
            ;;
        ubuntu|debian|pop|linuxmint|elementary|kali|raspbian)
            sudo apt update
            sudo apt install -y libgtk-3-dev libvte-2.91-dev build-essential
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if check_command "dnf"; then
                sudo dnf install -y gtk3-devel vte291-devel gcc make pkg-config
            else
                sudo yum install -y gtk3-devel vte291-devel gcc make pkg-config
            fi
            ;;
        opensuse*|suse)
            sudo zypper install -y gtk3-devel vte-devel gcc make pkg-config
            ;;
        void)
            sudo xbps-install -S gtk+3-devel vte3-devel base-devel
            ;;
        alpine)
            sudo apk add gtk+3.0-dev vte3-dev build-base
            ;;
        *)
            log WARN "Unknown distribution, attempting auto-detection..."
            if check_command "apt"; then
                sudo apt update && sudo apt install -y libgtk-3-dev libvte-2.91-dev build-essential
            elif check_command "dnf"; then
                sudo dnf install -y gtk3-devel vte291-devel gcc make
            elif check_command "pacman"; then
                sudo pacman -S --needed gtk3 vte3 base-devel
            else
                log ERROR "Could not install dependencies automatically"
                echo -e "\n${RED}Please install manually:${NC}"
                echo "  • GTK+ 3.0 development files"
                echo "  • VTE 2.91 development files"
                echo "  • Build essentials (gcc, make, pkg-config)"
                exit 1
            fi
            ;;
    esac
    
    log SUCCESS "Dependencies installed"
}

# ============================================================================
# BUILD CONFIGURATION
# ============================================================================

select_build_type() {
    if [ "$DEV_MODE" = true ]; then
        BUILD_TYPE="debug"
        return
    fi
    
    echo -e "${BOLD}Select Build Type:${NC}\n"
    echo "1. Release (optimized, recommended)"
    echo "2. Debug (with symbols and debugging)"
    echo "3. Custom (specify your own flags)"
    echo ""
    read -p "Choice [1]: " choice
    choice=${choice:-1}
    
    case $choice in
        1)
            BUILD_TYPE="release"
            log INFO "Selected release build"
            ;;
        2)
            BUILD_TYPE="debug"
            log INFO "Selected debug build"
            ;;
        3)
            BUILD_TYPE="custom"
            echo -e "\n${BOLD}Enter custom CFLAGS:${NC}"
            read -p "CFLAGS: " CUSTOM_CFLAGS
            log INFO "Using custom CFLAGS: $CUSTOM_CFLAGS"
            ;;
        *)
            BUILD_TYPE="release"
            log WARN "Invalid choice, defaulting to release"
            ;;
    esac
    echo ""
}

# ============================================================================
# BUILD PROCESS
# ============================================================================

create_makefile() {
    cat > Makefile << 'MAKEFILE_EOF'
CC = gcc
CFLAGS = -Wall -Wextra -O2 $(shell pkg-config --cflags gtk+-3.0 vte-2.91)
CFLAGS_DEBUG = -Wall -Wextra -g -O0 $(shell pkg-config --cflags gtk+-3.0 vte-2.91)
LDFLAGS = $(shell pkg-config --libs gtk+-3.0 vte-2.91)

TARGET = svte
SRC = svte.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

debug: $(SRC)
	$(CC) $(CFLAGS_DEBUG) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)

.PHONY: all debug clean
MAKEFILE_EOF
    log SUCCESS "Created Makefile"
}

build_svte() {
    log INFO "Starting build process..."
    
    cd "$SCRIPT_DIR" || exit 1
    
    # Create Makefile if missing
    if [ ! -f "Makefile" ]; then
        log WARN "Makefile not found, creating one..."
        create_makefile
    fi
    
    # Clean previous builds
    log INFO "Cleaning previous builds..."
    make clean &>/dev/null || true
    
    # Build based on type
    echo -e "${BOLD}Building SVTE...${NC}\n"
    
    local make_args=""
    local cpu_count=$(nproc 2>/dev/null || echo 1)
    
    case $BUILD_TYPE in
        release)
            make_args="-j$cpu_count"
            log INFO "Building with optimizations (-O2)"
            ;;
        debug)
            make_args="debug -j$cpu_count"
            log INFO "Building with debug symbols"
            ;;
        custom)
            make_args="-j$cpu_count CFLAGS=\"$CUSTOM_CFLAGS\""
            log INFO "Building with custom flags"
            ;;
    esac
    
    # Build
    if [ "$VERBOSE" = true ]; then
        eval make $make_args 2>&1 | tee -a "$LOG_FILE"
    else
        eval make $make_args >> "$LOG_FILE" 2>&1
    fi
    
    if [ -f "./svte" ]; then
        local size=$(ls -lh ./svte | awk '{print $5}')
        log SUCCESS "Build successful"
        echo -e "${GREEN}  ✓ Binary created${NC} ($size)"
        
        # Show binary info
        if check_command "file"; then
            local file_info=$(file ./svte)
            echo -e "${BLUE}  ℹ Type:${NC} ${file_info##*: }"
        fi
    else
        log ERROR "Build failed"
        echo -e "${RED}Build failed. Check the log: ${BLUE}$LOG_FILE${NC}"
        exit 1
    fi
}

# ============================================================================
# TESTING
# ============================================================================

run_tests() {
    log INFO "Running tests..."
    echo -e "\n${BOLD}Running Tests:${NC}\n"
    
    local test_count=0
    local passed=0
    
    # Test 1: Binary exists and is executable
    ((test_count++))
    if [ -x "./svte" ]; then
        echo -e "${GREEN}  ✓ Test $test_count: Binary is executable${NC}"
        ((passed++))
        log SUCCESS "Test $test_count passed: Binary executable"
    else
        echo -e "${RED}  ✗ Test $test_count: Binary not executable${NC}"
        log ERROR "Test $test_count failed: Binary not executable"
    fi
    
    # Test 2: Check dependencies
    ((test_count++))
    if command -v ldd &> /dev/null; then
        if ldd ./svte | grep -q "not found"; then
            echo -e "${RED}  ✗ Test $test_count: Missing runtime dependencies${NC}"
            ldd ./svte | grep "not found" | sed 's/^/    /'
            log ERROR "Test $test_count failed: Missing dependencies"
        else
            echo -e "${GREEN}  ✓ Test $test_count: All runtime dependencies satisfied${NC}"
            ((passed++))
            log SUCCESS "Test $test_count passed: Dependencies OK"
        fi
    else
        echo -e "${YELLOW}  ⚠ Test $test_count: Skipped (ldd not available)${NC}"
    fi
    
    # Test 3: Verify GTK/VTE linking
    ((test_count++))
    if ldd ./svte 2>/dev/null | grep -q "libgtk-3"; then
        echo -e "${GREEN}  ✓ Test $test_count: GTK+ 3 linked${NC}"
        ((passed++))
        log SUCCESS "Test $test_count passed: GTK linked"
    else
        echo -e "${RED}  ✗ Test $test_count: GTK+ 3 not linked${NC}"
        log ERROR "Test $test_count failed: GTK not linked"
    fi
    
    # Test 4: Verify VTE linking
    ((test_count++))
    if ldd ./svte 2>/dev/null | grep -q "libvte"; then
        echo -e "${GREEN}  ✓ Test $test_count: VTE linked${NC}"
        ((passed++))
        log SUCCESS "Test $test_count passed: VTE linked"
    else
        echo -e "${RED}  ✗ Test $test_count: VTE not linked${NC}"
        log ERROR "Test $test_count failed: VTE not linked"
    fi
    
    # Test 5: Check binary size (should be reasonable)
    ((test_count++))
    local size_bytes=$(stat -c%s ./svte 2>/dev/null || echo 0)
    if [ "$size_bytes" -gt 10000 ] && [ "$size_bytes" -lt 10000000 ]; then
        echo -e "${GREEN}  ✓ Test $test_count: Binary size reasonable ($size_bytes bytes)${NC}"
        ((passed++))
        log SUCCESS "Test $test_count passed: Size OK"
    else
        echo -e "${YELLOW}  ⚠ Test $test_count: Binary size unusual ($size_bytes bytes)${NC}"
        log WARN "Test $test_count: Unusual size"
    fi
    
    echo -e "\n${BOLD}Test Summary:${NC} ${GREEN}$passed${NC}/$test_count passed\n"
    log INFO "Tests complete: $passed/$test_count passed"
}

# ============================================================================
# OPTIONAL FEATURES
# ============================================================================

show_optional_features() {
    echo -e "${BOLD}Optional Setup Steps:${NC}\n"
    echo "1. Create desktop entry (for app menu)"
    echo "2. Create symlink in ~/bin"
    echo "3. Setup configuration file"
    echo "4. Generate documentation"
    echo "5. Run integration tests"
    echo "6. Skip all optional steps"
    echo ""
    
    read -p "Select features to set up (1-6, space-separated) [6]: " features
    features=${features:-6}
    
    for feature in $features; do
        case $feature in
            1)
                create_desktop_entry
                ;;
            2)
                create_symlink
                ;;
            3)
                setup_config
                ;;
            4)
                generate_docs
                ;;
            5)
                run_integration_tests
                ;;
            6)
                log INFO "Skipping optional features"
                break
                ;;
            *)
                log WARN "Unknown feature: $feature"
                ;;
        esac
    done
}

create_desktop_entry() {
    local desktop_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$desktop_dir"
    
    cat > "$desktop_dir/svte-local.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=SVTE Terminal (Local)
GenericName=Terminal Emulator
Comment=Simple VTE-based terminal emulator (local build)
Exec=$SCRIPT_DIR/svte
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
Keywords=terminal;shell;
StartupNotify=true
EOF
    
    chmod +x "$desktop_dir/svte-local.desktop"
    log SUCCESS "Desktop entry created"
    echo -e "${GREEN}  ✓ Desktop entry${NC} → $desktop_dir/svte-local.desktop"
}

create_symlink() {
    mkdir -p "$HOME/bin"
    
    if [ -L "$HOME/bin/svte" ]; then
        rm "$HOME/bin/svte"
    fi
    
    ln -s "$SCRIPT_DIR/svte" "$HOME/bin/svte"
    log SUCCESS "Symlink created"
    echo -e "${GREEN}  ✓ Symlink${NC} → $HOME/bin/svte"
    
    # Check if ~/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo -e "${YELLOW}  ⚠ Add $HOME/bin to PATH for easier access${NC}"
        echo -e "    Add to ~/.bashrc: ${BLUE}export PATH=\"\$HOME/bin:\$PATH\"${NC}"
    fi
}

setup_config() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/svte"
    mkdir -p "$config_dir"
    
    if [ ! -f "$config_dir/svte.conf" ]; then
        cat > "$config_dir/svte.conf" << 'EOF'
# SVTE Configuration - Development Build
[window]
width = 1000
height = 700

[font]
name = Monospace
size = 11

[colors]
scheme = gruvbox

[behavior]
scrollback_lines = 10000
EOF
        log SUCCESS "Configuration created"
        echo -e "${GREEN}  ✓ Config${NC} → $config_dir/svte.conf"
    else
        log INFO "Configuration already exists"
    fi
}

run_integration_tests() {
    echo -e "${BOLD}Integration Tests:${NC}\n"
    
    # Test with different backends
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        echo "Testing with X11 backend..."
        GDK_BACKEND=x11 timeout 2 ./svte --help &>/dev/null && \
            echo -e "${GREEN}  ✓ X11 backend works${NC}" || \
            echo -e "${YELLOW}  ⚠ X11 backend test failed${NC}"
        
        echo "Testing with Wayland backend..."
        GDK_BACKEND=wayland timeout 2 ./svte --help &>/dev/null && \
            echo -e "${GREEN}  ✓ Wayland backend works${NC}" || \
            echo -e "${YELLOW}  ⚠ Wayland backend test failed${NC}"
    else
        echo -e "${YELLOW}  ⚠ No display server detected, skipping${NC}"
    fi
}

generate_docs() {
    local doc_dir="$SCRIPT_DIR/docs"
    mkdir -p "$doc_dir"
    
    # Extract documentation from source
    if grep -q "// Documentation:" svte.c 2>/dev/null; then
        grep "^// " svte.c > "$doc_dir/api.txt"
        log SUCCESS "Documentation extracted"
        echo -e "${GREEN}  ✓ Documentation${NC} → $doc_dir/api.txt"
    else
        log INFO "No inline documentation found"
    fi
}

# ============================================================================
# MAIN SETUP FLOW
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            --dev|--debug)
                DEV_MODE=true
                BUILD_TYPE="debug"
                shift
                ;;
            --release)
                BUILD_TYPE="release"
                shift
                ;;
            --test-only)
                TEST_ONLY=true
                shift
                ;;
            -h|--help)
                echo "SVTE Terminal Setup Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -v, --verbose      Enable verbose output"
                echo "  --dev, --debug     Build in debug mode"
                echo "  --release          Build in release mode"
                echo "  --test-only        Only run tests on existing binary"
                echo "  -h, --help         Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    print_header
    
    log INFO "Setup started"
    log INFO "Log file: $LOG_FILE"
    
    echo -e "${BLUE}Setup Mode:${NC} ${BUILD_TYPE}"
    echo -e "${BLUE}Log File:${NC} $LOG_FILE\n"
    
    # Check for source files first
    check_source_files
    
    # If test-only mode
    if [ "$TEST_ONLY" = true ]; then
        if [ ! -f "./svte" ]; then
            log ERROR "No binary found to test"
            exit 1
        fi
        run_tests
        exit 0
    fi
    
    # System detection
    detect_distro
    
    # Check dependencies
    if ! check_dependencies; then
        echo -e "${YELLOW}Install missing dependencies? ${NC}[Y/n] "
        read -r response
        response=${response:-y}
        
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            install_dependencies
            echo ""
            check_dependencies
        else
            log ERROR "Cannot proceed without dependencies"
            exit 1
        fi
    fi
    echo ""
    
    # Build type selection
    if [ "$DEV_MODE" = false ]; then
        select_build_type
    else
        echo -e "${CYAN}Development mode enabled${NC}\n"
    fi
    
    # Build
    build_svte
    
    # Run tests
    echo ""
    run_tests
    
    # Optional features (unless in dev mode - then skip)
    if [ "$DEV_MODE" = false ]; then
        show_optional_features
    fi
    
    # Final summary
    echo -e "\n${GREEN}${BOLD}Setup Completed Successfully!${NC}\n"
    
    echo -e "${BOLD}Binary Location:${NC} ${BLUE}$SCRIPT_DIR/svte${NC}"
    echo -e "${BOLD}Build Type:${NC} ${CYAN}$BUILD_TYPE${NC}"
    
    echo -e "\n${BOLD}Quick Commands:${NC}"
    echo -e "  • Run terminal:       ${GREEN}./svte${NC}"
    echo -e "  • Install system:     ${GREEN}./install.sh${NC}"
    echo -e "  • Test X11:           ${GREEN}GDK_BACKEND=x11 ./svte${NC}"
    echo -e "  • Test Wayland:       ${GREEN}GDK_BACKEND=wayland ./svte${NC}"
    echo -e "  • Run tests:          ${GREEN}./setup.sh --test-only${NC}"
    echo -e "  • Clean build:        ${GREEN}make clean${NC}"
    
    if [ "$BUILD_TYPE" = "debug" ]; then
        echo -e "\n${BOLD}Debug Mode Enabled:${NC}"
        echo -e "  • Run with GDB:       ${GREEN}gdb ./svte${NC}"
        echo -e "  • Run with Valgrind:  ${GREEN}valgrind ./svte${NC}"
    fi
    
    echo -e "\n${BOLD}Log File:${NC} ${BLUE}$LOG_FILE${NC}"
    
    # Offer to run
    echo -e "\n${YELLOW}Launch SVTE now? ${NC}[y/N] "
    read -r -t 10 response || response="n"
    
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${GREEN}Launching SVTE...${NC}"
        log INFO "Launching SVTE"
        ./svte &
        echo -e "${GREEN}✓ SVTE launched!${NC}"
    fi
    
    echo -e "\n${GREEN}${BOLD}Setup complete!${NC}\n"
}

# Run main function
main "$@"
