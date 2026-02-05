#!/bin/bash
# SVTE Terminal installer - builds and installs the terminal emulator

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   SVTE Terminal Emulator Installer    ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════╝${NC}\n"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run this script as root${NC}"
    echo "Run as normal user, sudo will be used when needed"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}Cannot detect distribution${NC}"
    exit 1
fi

echo -e "${BLUE}Detected distribution:${NC} $DISTRO\n"

# Check if dependencies are installed
echo -e "${BOLD}Step 1/5: Checking dependencies...${NC}"
if pkg-config --exists gtk+-3.0 vte-2.91 2>/dev/null; then
    echo -e "${GREEN}✓ GTK+ $(pkg-config --modversion gtk+-3.0)${NC}"
    echo -e "${GREEN}✓ VTE $(pkg-config --modversion vte-2.91)${NC}"
else
    echo -e "${YELLOW}⚠ Dependencies not found${NC}\n"
    echo "Installing required packages..."
    
    case $DISTRO in
        arch|manjaro|endeavouros)
            sudo pacman -S --needed gtk3 vte3
            ;;
        ubuntu|debian|pop|linuxmint|elementary)
            sudo apt update
            sudo apt install -y libgtk-3-dev libvte-2.91-dev
            ;;
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf install -y gtk3-devel vte291-devel
            ;;
        opensuse*|suse)
            sudo zypper install -y gtk3-devel vte-devel
            ;;
        *)
            echo -e "${RED}Unknown distribution: $DISTRO${NC}"
            echo "Please install manually:"
            echo "  - GTK+ 3.0 development files"
            echo "  - VTE 2.91 development files"
            exit 1
            ;;
    esac
    echo -e "${GREEN}✓ Dependencies installed${NC}"
fi

# Build
echo -e "\n${BOLD}Step 2/5: Building SVTE...${NC}"
if ! [ -f "svte.c" ]; then
    echo -e "${RED}✗ svte.c not found${NC}"
    echo "Please run this script from the svte directory"
    exit 1
fi

if make clean && make; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# Install binary
echo -e "\n${BOLD}Step 3/5: Installing binary...${NC}"
if [ -f "./svte" ]; then
    sudo install -Dm755 svte /usr/local/bin/svte
    echo -e "${GREEN}✓ Installed to /usr/local/bin/svte${NC}"
else
    echo -e "${RED}✗ Binary not found${NC}"
    exit 1
fi

# Create desktop entry
echo -e "\n${BOLD}Step 4/5: Creating desktop entry...${NC}"

# Install icon
ICON_PATH="/usr/local/share/pixmaps/svte.svg"
sudo mkdir -p /usr/local/share/pixmaps

if [ -f "svte.svg" ]; then
    sudo cp svte.svg "$ICON_PATH"
    echo -e "${GREEN}✓ Installed icon${NC}"
else
    # Create a simple SVG icon
    sudo tee "$ICON_PATH" > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="48" height="48" version="1.1" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
 <rect x="4" y="4" width="40" height="40" rx="4" fill="#282828"/>
 <rect x="6" y="6" width="36" height="36" rx="3" fill="#3c3836"/>
 <text x="10" y="26" fill="#ebdbb2" font-family="monospace" font-size="16" font-weight="bold">&gt;_</text>
 <rect x="10" y="30" width="12" height="2" fill="#fabd2f"/>
</svg>
EOF
    echo -e "${GREEN}✓ Created default icon${NC}"
fi

# Create desktop entry
sudo tee /usr/share/applications/svte.desktop > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=SVTE Terminal
GenericName=Terminal Emulator
Comment=Simple VTE-based terminal emulator
Exec=/usr/local/bin/svte
Icon=svte
Terminal=false
Categories=System;TerminalEmulator;
Keywords=terminal;shell;prompt;command;commandline;
StartupNotify=true
Actions=new-window;

[Desktop Action new-window]
Name=Open New Window
Exec=/usr/local/bin/svte
EOF

echo -e "${GREEN}✓ Desktop entry created${NC}"

# Update desktop database
echo -e "\n${BOLD}Step 5/5: Updating desktop database...${NC}"
if command -v update-desktop-database &> /dev/null; then
    sudo update-desktop-database /usr/share/applications
    echo -e "${GREEN}✓ Desktop database updated${NC}"
else
    echo -e "${YELLOW}⚠ update-desktop-database not found (optional)${NC}"
fi

# Verify installation
echo -e "\n${BOLD}Verifying installation...${NC}"
if command -v svte &> /dev/null; then
    INSTALLED_PATH=$(which svte)
    echo -e "${GREEN}✓ svte installed at: $INSTALLED_PATH${NC}"
    
    # Show file size
    SIZE=$(ls -lh "$INSTALLED_PATH" | awk '{print $5}')
    echo -e "${GREEN}✓ Binary size: $SIZE${NC}"
else
    echo -e "${RED}✗ Installation verification failed${NC}"
    exit 1
fi

# Success message
echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║     Installation successful! 🚀        ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════╝${NC}\n"

echo -e "${BOLD}You can now:${NC}"
echo -e "  • Run from terminal: ${GREEN}svte${NC}"
echo -e "  • Find in applications menu: ${GREEN}SVTE Terminal${NC}"
echo -e "  • Set as default terminal in system settings"

echo -e "\n${BOLD}Installed files:${NC}"
echo -e "  • Binary: ${BLUE}/usr/local/bin/svte${NC}"
echo -e "  • Desktop entry: ${BLUE}/usr/share/applications/svte.desktop${NC}"
echo -e "  • Icon: ${BLUE}/usr/local/share/pixmaps/svte.svg${NC}"

echo -e "\n${BOLD}To uninstall:${NC}"
echo -e "  ${BLUE}./uninstall.sh${NC} or ${BLUE}sudo make uninstall${NC}"

echo -e "\n${YELLOW}Would you like to launch SVTE now? (y/n)${NC} "
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Launching SVTE..."
    svte &
    echo -e "${GREEN}✓ SVTE launched!${NC}"
fi

echo -e "\n${GREEN}Enjoy your new terminal! 🎉${NC}\n"
