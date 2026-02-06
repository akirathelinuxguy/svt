#!/bin/bash
# SVTE Terminal Emulator - Installation Script (Fixed Version)
# Features: Better error handling, source file detection, helpful error messages

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

VERSION="1.0.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/svte-install-$(date +%Y%m%d-%H%M%S).log"
VERBOSE=false

# Installation paths
PREFIX="${PREFIX:-/usr/local}"
BINDIR="$PREFIX/bin"
DATADIR="$PREFIX/share"
APPLICATIONSDIR="$DATADIR/applications"
PIXMAPSDIR="$DATADIR/pixmaps"
ICONDIR="$DATADIR/icons/hicolor"

# Color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

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
    log ERROR "Installation failed at line $line_number with exit code $exit_code"
    log ERROR "Check log file: $LOG_FILE"
    echo -e "\n${RED}${BOLD}Installation failed!${NC}"
    echo -e "Log file: ${BLUE}$LOG_FILE${NC}\n"
    exit "$exit_code"
}

trap 'handle_error $? $LINENO' ERR

show_progress() {
    local current=$1
    local total=$2
    local message=$3
    
    local percent=$((current * 100 / total))
    local bar_length=40
    local filled=$((bar_length * current / total))
    
    printf "\r${BOLD}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((bar_length - filled))s" | tr ' ' '░'
    printf "] %3d%% ${NC}- %s" "$percent" "$message"
    
    [ "$current" -eq "$total" ] && echo
}

check_command() {
    command -v "$1" &> /dev/null
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${CYAN}${spin:$i:1}${NC} %s" "$message"
        sleep 0.1
    done
    printf "\r"
}

# ============================================================================
# HEADER
# ============================================================================

print_header() {
    clear
    echo -e "${BOLD}${MAGENTA}SVTE Terminal Emulator - Installer v1.0.1${NC}\n"
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

check_root() {
    if [ "$EUID" -eq 0 ]; then 
        log ERROR "Please do not run this script as root"
        echo -e "${RED}Please do not run this script as root${NC}"
        echo "Run as normal user, sudo will be used when needed"
        exit 1
    fi
    log INFO "Root check passed"
}

check_source_files() {
    log INFO "Checking for required source files..."
    
    local missing_files=()
    local required_files=("svte.c")
    local optional_files=("Makefile" "svte.svg" "README.md")
    
    # Check required files
    for file in "${required_files[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            missing_files+=("$file (REQUIRED)")
        fi
    done
    
    # Check optional files
    for file in "${optional_files[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            log WARN "Optional file missing: $file"
        else
            log DEBUG "Found optional file: $file"
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}${BOLD}ERROR: Missing required source files!${NC}\n"
        echo -e "${YELLOW}Missing files:${NC}"
        printf '  • %s\n' "${missing_files[@]}"
        echo ""
        echo -e "${BOLD}This installation script requires the SVTE source code.${NC}"
        echo -e "${CYAN}Expected files in ${BOLD}$SCRIPT_DIR${NC}${CYAN}:${NC}"
        echo -e "  ${GREEN}✓ svte.c${NC}         - Main source code (REQUIRED)"
        echo -e "  ${BLUE}○ Makefile${NC}      - Build configuration (will be auto-generated if missing)"
        echo -e "  ${BLUE}○ svte.svg${NC}      - Application icon (will use default if missing)"
        echo -e "  ${BLUE}○ README.md${NC}     - Documentation"
        echo ""
        echo -e "${YELLOW}Possible solutions:${NC}"
        echo -e "1. If you have the source code elsewhere, copy it to this directory:"
        echo -e "   ${BLUE}cp /path/to/svte.c $SCRIPT_DIR/${NC}"
        echo ""
        echo -e "2. If you need to download the source code:"
        echo -e "   ${BLUE}git clone <repository-url> && cd svte${NC}"
        echo -e "   ${BLUE}./install.sh${NC}"
        echo ""
        echo -e "3. If you only have a compiled binary:"
        echo -e "   ${BLUE}sudo install -Dm755 ./svte /usr/local/bin/svte${NC}"
        echo ""
        log ERROR "Missing required source files: ${missing_files[*]}"
        exit 1
    fi
    
    log SUCCESS "All required source files found"
    echo -e "${GREEN}✓ Source files verified${NC}\n"
}

check_system() {
    log INFO "Performing system checks..."
    
    # Check if we're on Linux
    if [ "$(uname -s)" != "Linux" ]; then
        log ERROR "This script only works on Linux systems"
        exit 1
    fi
    
    # Check required tools
    local required_tools=("gcc" "make" "pkg-config" "install")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! check_command "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log WARN "Missing build tools: ${missing_tools[*]}"
        log INFO "Installing build essentials..."
        install_build_tools
    else
        log SUCCESS "All build tools found"
    fi
}

install_build_tools() {
    if check_command "apt"; then
        sudo apt update && sudo apt install -y build-essential pkg-config
    elif check_command "dnf"; then
        sudo dnf groupinstall -y "Development Tools"
    elif check_command "pacman"; then
        sudo pacman -S --needed --noconfirm base-devel
    elif check_command "zypper"; then
        sudo zypper install -y -t pattern devel_basis
    else
        log ERROR "Could not install build tools automatically"
        echo -e "${YELLOW}Please install manually:${NC}"
        echo "  • gcc"
        echo "  • make"
        echo "  • pkg-config"
        exit 1
    fi
    log SUCCESS "Build tools installed"
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
    echo -e "${BLUE}Version:${NC} $DISTRO_VERSION\n"
}

# ============================================================================
# DEPENDENCY MANAGEMENT
# ============================================================================

check_dependencies() {
    log INFO "Checking dependencies..."
    local missing_deps=()
    
    # Check for GTK+ 3.0
    if ! pkg-config --exists gtk+-3.0 2>/dev/null; then
        missing_deps+=("gtk+-3.0")
    else
        local gtk_version=$(pkg-config --modversion gtk+-3.0)
        log SUCCESS "GTK+ $gtk_version found"
        echo -e "${GREEN}  ✓ GTK+ ${NC}$gtk_version"
    fi
    
    # Check for VTE 2.91
    if ! pkg-config --exists vte-2.91 2>/dev/null; then
        missing_deps+=("vte-2.91")
    else
        local vte_version=$(pkg-config --modversion vte-2.91)
        log SUCCESS "VTE $vte_version found"
        echo -e "${GREEN}  ✓ VTE ${NC}$vte_version"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log WARN "Missing dependencies: ${missing_deps[*]}"
        return 1
    else
        log SUCCESS "All dependencies satisfied"
        return 0
    fi
}

install_dependencies() {
    log INFO "Installing dependencies for $DISTRO_ID..."
    
    case $DISTRO_ID in
        arch|manjaro|endeavouros|artix|garuda)
            log INFO "Using pacman package manager"
            sudo pacman -Sy --needed --noconfirm gtk3 vte3
            ;;
            
        ubuntu|debian|pop|linuxmint|elementary|kali|raspbian|neon)
            log INFO "Using apt package manager"
            sudo apt update
            sudo apt install -y libgtk-3-dev libvte-2.91-dev
            ;;
            
        fedora|rhel|centos|rocky|almalinux)
            log INFO "Using dnf/yum package manager"
            if check_command "dnf"; then
                sudo dnf install -y gtk3-devel vte291-devel
            else
                sudo yum install -y gtk3-devel vte291-devel
            fi
            ;;
            
        opensuse*|suse|sles)
            log INFO "Using zypper package manager"
            sudo zypper install -y gtk3-devel vte-devel
            ;;
            
        gentoo)
            log INFO "Using emerge package manager"
            sudo emerge -av x11-libs/gtk+:3 x11-libs/vte
            ;;
            
        void)
            log INFO "Using xbps package manager"
            sudo xbps-install -S gtk+3-devel vte3-devel
            ;;
            
        alpine)
            log INFO "Using apk package manager"
            sudo apk add gtk+3.0-dev vte3-dev build-base
            ;;
            
        nixos)
            log ERROR "NixOS detected - please use nix-env or add to configuration.nix"
            echo "Add to your configuration.nix:"
            echo "  environment.systemPackages = with pkgs; [ gtk3 vte ];"
            exit 1
            ;;
            
        *)
            # Try to auto-detect package manager
            log WARN "Unknown distribution: $DISTRO_ID"
            log INFO "Attempting auto-detection..."
            
            if check_command "apt"; then
                log INFO "Found apt, trying Debian/Ubuntu packages..."
                sudo apt update
                sudo apt install -y libgtk-3-dev libvte-2.91-dev
            elif check_command "dnf"; then
                log INFO "Found dnf, trying Fedora packages..."
                sudo dnf install -y gtk3-devel vte291-devel
            elif check_command "pacman"; then
                log INFO "Found pacman, trying Arch packages..."
                sudo pacman -S --needed --noconfirm gtk3 vte3
            elif check_command "zypper"; then
                log INFO "Found zypper, trying openSUSE packages..."
                sudo zypper install -y gtk3-devel vte-devel
            else
                log ERROR "Could not determine package manager"
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
# BUILD PROCESS
# ============================================================================

build_svte() {
    log INFO "Starting build process..."
    
    cd "$SCRIPT_DIR" || exit 1
    
    # Makefile handling
    if [ ! -f "Makefile" ]; then
        log WARN "Makefile not found, creating one..."
        create_makefile
    fi
    
    # Clean previous builds
    log INFO "Cleaning previous builds..."
    make clean &>/dev/null || true
    
    # Build with progress
    log INFO "Compiling SVTE..."
    if [ "$VERBOSE" = true ]; then
        make -j$(nproc) 2>&1 | tee -a "$LOG_FILE"
    else
        make -j$(nproc) >> "$LOG_FILE" 2>&1 &
        spinner $! "Compiling SVTE..."
    fi
    
    if [ -f "./svte" ]; then
        local size=$(ls -lh ./svte | awk '{print $5}')
        log SUCCESS "Build successful - Binary size: $size"
        echo -e "${GREEN}  ✓ Binary created${NC} ($size)"
    else
        log ERROR "Build failed - binary not created"
        echo -e "${RED}Build failed. Check the log file for details:${NC}"
        echo -e "${BLUE}$LOG_FILE${NC}"
        exit 1
    fi
    
    # Verify binary
    if [ -x "./svte" ]; then
        log SUCCESS "Binary is executable"
    else
        log ERROR "Binary is not executable"
        exit 1
    fi
    
    # Check dependencies
    log INFO "Verifying runtime dependencies..."
    if command -v ldd &> /dev/null; then
        if ldd ./svte | grep -q "not found"; then
            log ERROR "Missing runtime dependencies:"
            ldd ./svte | grep "not found" | tee -a "$LOG_FILE"
            exit 1
        else
            log SUCCESS "All runtime dependencies satisfied"
        fi
    fi
}

create_makefile() {
    cat > Makefile << 'MAKEFILE_EOF'
CC = gcc
CFLAGS = -Wall -Wextra -O2 $(shell pkg-config --cflags gtk+-3.0 vte-2.91)
LDFLAGS = $(shell pkg-config --libs gtk+-3.0 vte-2.91)

TARGET = svte
SRC = svte.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	install -Dm755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/$(TARGET)

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(TARGET)

.PHONY: all clean install uninstall
MAKEFILE_EOF
    log SUCCESS "Created Makefile"
}

# ============================================================================
# INSTALLATION
# ============================================================================

install_binary() {
    log INFO "Installing binary..."
    
    sudo mkdir -p "$BINDIR"
    
    if sudo install -Dm755 ./svte "$BINDIR/svte"; then
        log SUCCESS "Installed binary to $BINDIR/svte"
        echo -e "${GREEN}  ✓ Binary${NC} → $BINDIR/svte"
    else
        log ERROR "Failed to install binary"
        exit 1
    fi
}

install_icon() {
    log INFO "Installing icon..."
    
    local icon_dirs=(
        "$ICONDIR/scalable/apps"
        "$PIXMAPSDIR"
    )
    
    local icon_installed=false
    
    for dir in "${icon_dirs[@]}"; do
        sudo mkdir -p "$dir"
    done
    
    if [ -f "svte.svg" ]; then
        for dir in "${icon_dirs[@]}"; do
            if sudo install -Dm644 svte.svg "$dir/svte.svg" 2>/dev/null; then
                log DEBUG "Icon installed to $dir/svte.svg"
                icon_installed=true
            fi
        done
        log SUCCESS "Custom icon installed"
    else
        log INFO "Creating default icon..."
        create_default_icon
        icon_installed=true
    fi
    
    if check_command "gtk-update-icon-cache"; then
        log INFO "Updating icon cache..."
        sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
        log SUCCESS "Icon cache updated"
    fi
    
    if [ "$icon_installed" = true ]; then
        echo -e "${GREEN}  ✓ Icon${NC} → Multiple locations"
    fi
}

create_default_icon() {
    local icon_content='<?xml version="1.0" encoding="UTF-8"?>
<svg width="128" height="128" version="1.1" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#458588;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#83a598;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect x="8" y="8" width="112" height="112" rx="16" ry="16" fill="#282828"/>
  <rect x="12" y="12" width="104" height="104" rx="12" ry="12" fill="#1d2021"/>
  <rect x="12" y="12" width="104" height="24" rx="12" ry="12" fill="#3c3836"/>
  <rect x="12" y="24" width="104" height="12" fill="#3c3836"/>
  <circle cx="24" cy="24" r="4" fill="#fb4934"/>
  <circle cx="36" cy="24" r="4" fill="#fabd2f"/>
  <circle cx="48" cy="24" r="4" fill="#b8bb26"/>
  <text x="20" y="60" font-family="monospace" font-size="20" font-weight="bold" fill="#b8bb26">$</text>
  <text x="36" y="60" font-family="monospace" font-size="20" font-weight="bold" fill="#ebdbb2">svte</text>
  <rect x="20" y="68" width="12" height="3" fill="#fabd2f"/>
  <text x="20" y="82" font-family="monospace" font-size="12" fill="#928374">~/projects</text>
  <rect x="20" y="86" width="60" height="2" fill="#504945" opacity="0.5"/>
  <text x="20" y="98" font-family="monospace" font-size="12" fill="#928374">simple &amp; fast</text>
  <rect x="20" y="102" width="45" height="2" fill="#504945" opacity="0.5"/>
  <path d="M 100 100 L 108 100 L 108 108 L 100 100" fill="url(#grad1)" opacity="0.5"/>
  <rect x="8" y="8" width="112" height="112" rx="16" ry="16" fill="none" stroke="#458588" stroke-width="2" opacity="0.4"/>
</svg>'
    
    echo "$icon_content" | sudo tee "$PIXMAPSDIR/svte.svg" > /dev/null
    echo "$icon_content" | sudo tee "$ICONDIR/scalable/apps/svte.svg" > /dev/null
    log SUCCESS "Default icon created"
}

install_desktop_entry() {
    log INFO "Installing desktop entry..."
    
    sudo mkdir -p "$APPLICATIONSDIR"
    
    sudo tee "$APPLICATIONSDIR/svte.desktop" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=SVTE Terminal
GenericName=Terminal Emulator
Comment=Simple VTE-based terminal emulator with tabs and Sixel support
TryExec=$BINDIR/svte
Exec=$BINDIR/svte %F
Icon=svte
Terminal=false
Categories=System;TerminalEmulator;GTK;Utility;
Keywords=terminal;shell;prompt;command;commandline;cli;bash;zsh;fish;console;
StartupNotify=true
StartupWMClass=svte
Actions=new-window;

[Desktop Action new-window]
Name=New Window
Exec=$BINDIR/svte
EOF
    
    log SUCCESS "Desktop entry created"
    echo -e "${GREEN}  ✓ Desktop entry${NC} → $APPLICATIONSDIR/svte.desktop"
    
    if check_command "desktop-file-validate"; then
        if desktop-file-validate "$APPLICATIONSDIR/svte.desktop" 2>/dev/null; then
            log SUCCESS "Desktop file validated"
        else
            log WARN "Desktop file validation had warnings (non-critical)"
        fi
    fi
    
    if check_command "update-desktop-database"; then
        log INFO "Updating desktop database..."
        sudo update-desktop-database "$APPLICATIONSDIR" 2>/dev/null || true
        log SUCCESS "Desktop database updated"
    fi
}

setup_user_config() {
    log INFO "Setting up user configuration..."
    
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/svte"
    mkdir -p "$config_dir"
    
    if [ ! -f "$config_dir/svte.conf" ]; then
        cat > "$config_dir/svte.conf" << 'EOF'
# SVTE Configuration File
# Customize your terminal settings here

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
        log SUCCESS "Configuration file created"
        echo -e "${GREEN}  ✓ Config${NC} → $config_dir/svte.conf"
    else
        log INFO "Configuration file already exists"
    fi
}

verify_installation() {
    log INFO "Verifying installation..."
    
    local errors=0
    
    echo -e "\n${BOLD}Installation Verification:${NC}\n"
    
    # Check binary
    if [ -x "$BINDIR/svte" ]; then
        local size=$(ls -lh "$BINDIR/svte" | awk '{print $5}')
        echo -e "${GREEN}  ✓ Binary is executable${NC} ($size)"
        log SUCCESS "Binary verification passed"
    else
        echo -e "${RED}  ✗ Binary not found or not executable${NC}"
        log ERROR "Binary verification failed"
        ((errors++))
    fi
    
    # Check PATH
    if command -v svte &> /dev/null; then
        echo -e "${GREEN}  ✓ Binary in PATH${NC}"
        log SUCCESS "PATH verification passed"
    else
        echo -e "${YELLOW}  ⚠ Binary not in PATH${NC}"
        log WARN "Binary not in PATH - may need to restart shell"
    fi
    
    # Check desktop entry
    if [ -f "$APPLICATIONSDIR/svte.desktop" ]; then
        echo -e "${GREEN}  ✓ Desktop entry exists${NC}"
        log SUCCESS "Desktop entry verification passed"
    else
        echo -e "${RED}  ✗ Desktop entry missing${NC}"
        log ERROR "Desktop entry verification failed"
        ((errors++))
    fi
    
    # Check icon
    local icon_found=false
    for dir in "$PIXMAPSDIR" "$ICONDIR/scalable/apps"; do
        if [ -f "$dir/svte.svg" ]; then
            icon_found=true
            break
        fi
    done
    
    if [ "$icon_found" = true ]; then
        echo -e "${GREEN}  ✓ Icon installed${NC}"
        log SUCCESS "Icon verification passed"
    else
        echo -e "${YELLOW}  ⚠ Icon not found${NC}"
        log WARN "Icon verification failed (non-critical)"
    fi
    
    # Check runtime dependencies
    if command -v ldd &> /dev/null; then
        if ldd "$BINDIR/svte" 2>/dev/null | grep -q "not found"; then
            echo -e "${RED}  ✗ Missing runtime dependencies${NC}"
            ldd "$BINDIR/svte" | grep "not found"
            log ERROR "Runtime dependencies missing"
            ((errors++))
        else
            echo -e "${GREEN}  ✓ All runtime dependencies satisfied${NC}"
            log SUCCESS "Runtime dependencies verified"
        fi
    fi
    
    # Test execution
    if timeout 2 "$BINDIR/svte" --version &>/dev/null || timeout 2 "$BINDIR/svte" --help &>/dev/null; then
        echo -e "${GREEN}  ✓ Binary executes successfully${NC}"
        log SUCCESS "Execution test passed"
    else
        echo -e "${YELLOW}  ⚠ Could not verify execution${NC}"
        log WARN "Execution test inconclusive"
    fi
    
    echo ""
    
    if [ $errors -eq 0 ]; then
        log SUCCESS "All verification checks passed"
        return 0
    else
        log WARN "Verification completed with $errors error(s)"
        return 1
    fi
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================

main() {
    local start_time=$(date +%s)
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            --prefix)
                PREFIX="$2"
                BINDIR="$PREFIX/bin"
                DATADIR="$PREFIX/share"
                APPLICATIONSDIR="$DATADIR/applications"
                PIXMAPSDIR="$DATADIR/pixmaps"
                ICONDIR="$DATADIR/icons/hicolor"
                shift 2
                ;;
            -h|--help)
                echo "SVTE Terminal Installer"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -v, --verbose      Enable verbose output"
                echo "  --prefix DIR       Install to custom prefix (default: /usr/local)"
                echo "  -h, --help         Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done
    
    print_header
    
    log INFO "Installation started"
    log INFO "Log file: $LOG_FILE"
    
    # Installation steps
    echo -e "${BOLD}${BLUE}Starting installation...${NC}\n"
    
    # Step 1: Check source files
    echo -e "${BOLD}[1/9]${NC} Checking source files..."
    check_source_files
    
    # Step 2: Pre-flight checks
    echo -e "${BOLD}[2/9]${NC} Performing pre-flight checks..."
    check_root
    check_system
    detect_distro
    echo ""
    
    # Step 3: Check dependencies
    echo -e "${BOLD}[3/9]${NC} Checking dependencies..."
    if ! check_dependencies; then
        echo -e "\n${YELLOW}Installing missing dependencies...${NC}\n"
        install_dependencies
        echo ""
        # Verify again
        if ! check_dependencies; then
            log ERROR "Dependency installation failed"
            exit 1
        fi
    fi
    echo ""
    
    # Step 4: Build
    echo -e "${BOLD}[4/9]${NC} Building SVTE..."
    build_svte
    echo ""
    
    # Step 5: Install binary
    echo -e "${BOLD}[5/9]${NC} Installing binary..."
    install_binary
    echo ""
    
    # Step 6: Install icon
    echo -e "${BOLD}[6/9]${NC} Installing icon..."
    install_icon
    echo ""
    
    # Step 7: Install desktop entry
    echo -e "${BOLD}[7/9]${NC} Installing desktop entry..."
    install_desktop_entry
    echo ""
    
    # Step 8: Setup config
    echo -e "${BOLD}[8/9]${NC} Setting up configuration..."
    setup_user_config
    echo ""
    
    # Step 9: Verify
    echo -e "${BOLD}[9/9]${NC} Verifying installation..."
    verify_installation
    
    # Calculate installation time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Success message
    echo -e "\n${GREEN}${BOLD}Installation Completed Successfully!${NC}\n"
    
    log SUCCESS "Installation completed in ${duration}s"
    
    echo -e "${BOLD}Quick Start:${NC}"
    echo -e "  • Run from terminal:    ${GREEN}svte${NC}"
    echo -e "  • Launch from menu:     ${GREEN}SVTE Terminal${NC}"
    echo -e "  • View configuration:   ${BLUE}cat ~/.config/svte/svte.conf${NC}"
    
    echo -e "\n${BOLD}Installed Files:${NC}"
    echo -e "  • Binary:         ${BLUE}$BINDIR/svte${NC}"
    echo -e "  • Desktop entry:  ${BLUE}$APPLICATIONSDIR/svte.desktop${NC}"
    echo -e "  • Icon:           ${BLUE}$PIXMAPSDIR/svte.svg${NC}"
    echo -e "  • Config:         ${BLUE}~/.config/svte/svte.conf${NC}"
    
    echo -e "\n${BOLD}To Uninstall:${NC}"
    echo -e "  ${BLUE}./uninstall.sh${NC}"
    
    echo -e "\n${BOLD}Log File:${NC} ${BLUE}$LOG_FILE${NC}"
    
    # Offer to launch
    echo -e "\n${YELLOW}Would you like to launch SVTE now? ${NC}[y/N] "
    read -r -t 10 response || response="n"
    
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${GREEN}Launching SVTE...${NC}"
        log INFO "Launching SVTE"
        nohup "$BINDIR/svte" &>/dev/null &
        echo -e "${GREEN}✓ SVTE launched!${NC}"
    fi
    
    echo -e "\n${GREEN}${BOLD}Thank you for installing SVTE!${NC}\n"
}

# Run main function
main "$@"
