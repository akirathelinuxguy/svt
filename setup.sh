#!/bin/bash
# SVTE setup script - helps install dependencies and build

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BOLD}SVTE Terminal Emulator - Setup${NC}\n"

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}Cannot detect distribution${NC}"
    exit 1
fi

echo -e "Detected distribution: ${GREEN}$DISTRO${NC}\n"

# Check if dependencies are already installed
echo "Checking dependencies..."
if pkg-config --exists gtk+-3.0 vte-2.91 2>/dev/null; then
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
    GTK_VER=$(pkg-config --modversion gtk+-3.0)
    VTE_VER=$(pkg-config --modversion vte-2.91)
    echo "  GTK+ version: $GTK_VER"
    echo "  VTE version: $VTE_VER"
else
    echo -e "${YELLOW}Dependencies not found, need to install${NC}\n"
    
    # Install based on distro
    case $DISTRO in
        arch|manjaro|endeavouros)
            echo "Installing for Arch Linux..."
            sudo pacman -S --needed gtk3 vte3
            ;;
        ubuntu|debian|pop|linuxmint)
            echo "Installing for Debian/Ubuntu..."
            sudo apt update
            sudo apt install -y libgtk-3-dev libvte-2.91-dev
            ;;
        fedora|rhel|centos)
            echo "Installing for Fedora/RHEL..."
            sudo dnf install -y gtk3-devel vte291-devel
            ;;
        opensuse*|suse)
            echo "Installing for openSUSE..."
            sudo zypper install -y gtk3-devel vte-devel
            ;;
        *)
            echo -e "${YELLOW}Unknown distribution: $DISTRO${NC}"
            echo "Please install manually:"
            echo "  - GTK+ 3.0 development files"
            echo "  - VTE 2.91 development files"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}✓ Dependencies installed${NC}"
fi

# Build
echo -e "\n${BOLD}Building SVTE...${NC}"
if make; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# Test run
echo -e "\n${BOLD}Testing...${NC}"
if [ -f ./svte ]; then
    SIZE=$(ls -lh ./svte | awk '{print $5}')
    echo -e "${GREEN}✓ Binary created: $SIZE${NC}"
    
    # Show binary info
    if command -v ldd &> /dev/null; then
        echo -e "\nDependencies:"
        ldd ./svte | grep -E "(gtk|vte|glib)" | head -5
    fi
else
    echo -e "${RED}✗ Binary not found${NC}"
    exit 1
fi

# Installation prompt
echo -e "\n${BOLD}Installation${NC}"
echo "Binary created: ./svte"
echo ""
echo "To install system-wide:"
echo -e "  ${GREEN}sudo make install${NC}"
echo ""
echo "To run from current directory:"
echo -e "  ${GREEN}./svte${NC}"
echo ""
echo "To test with different backends:"
echo -e "  ${GREEN}GDK_BACKEND=wayland ./svte${NC}"
echo -e "  ${GREEN}GDK_BACKEND=x11 ./svte${NC}"

# Optional: Ask to run
echo -e "\n${YELLOW}Would you like to test run SVTE now? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Launching SVTE..."
    ./svte &
    echo -e "${GREEN}SVTE launched!${NC}"
fi

echo -e "\n${GREEN}Setup complete!${NC} 🚀"
