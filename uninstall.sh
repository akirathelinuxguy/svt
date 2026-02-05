#!/bin/bash
# SVTE uninstaller - removes all installed files

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   SVTE Terminal Emulator Uninstaller  ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════╝${NC}\n"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run this script as root${NC}"
    echo "Run as normal user, sudo will be used when needed"
    exit 1
fi

# Check if svte is installed
if ! command -v svte &> /dev/null; then
    echo -e "${YELLOW}⚠ SVTE does not appear to be installed${NC}"
    echo -e "\nSearching for installed files anyway...\n"
fi

# List files to be removed
echo -e "${BOLD}The following files will be removed:${NC}\n"

FILES_TO_REMOVE=(
    "/usr/local/bin/svte"
    "/usr/share/applications/svte.desktop"
    "/usr/local/share/pixmaps/svte.svg"
)

FOUND_FILES=()

for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ] || [ -L "$file" ]; then
        echo -e "  ${RED}✗${NC} $file"
        FOUND_FILES+=("$file")
    else
        echo -e "  ${BLUE}○${NC} $file ${BLUE}(not found)${NC}"
    fi
done

if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    echo -e "\n${GREEN}No SVTE files found. Already uninstalled?${NC}\n"
    exit 0
fi

# Confirmation
echo -e "\n${YELLOW}${BOLD}Are you sure you want to uninstall SVTE? (y/n)${NC} "
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "${BLUE}Uninstall cancelled${NC}"
    exit 0
fi

# Check for running instances
echo -e "\n${BOLD}Checking for running instances...${NC}"
if pgrep -x svte > /dev/null; then
    echo -e "${YELLOW}⚠ SVTE is currently running${NC}"
    echo -e "${YELLOW}Would you like to close all running instances? (y/n)${NC} "
    read -r kill_response
    if [[ "$kill_response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        pkill -x svte
        echo -e "${GREEN}✓ Closed running instances${NC}"
        sleep 1
    else
        echo -e "${YELLOW}⚠ Continuing with uninstall (some files may be in use)${NC}"
    fi
else
    echo -e "${GREEN}✓ No running instances${NC}"
fi

# Remove files
echo -e "\n${BOLD}Removing files...${NC}"

for file in "${FOUND_FILES[@]}"; do
    if sudo rm -f "$file" 2>/dev/null; then
        echo -e "${GREEN}✓ Removed:${NC} $file"
    else
        echo -e "${RED}✗ Failed to remove:${NC} $file"
    fi
done

# Update desktop database
echo -e "\n${BOLD}Updating desktop database...${NC}"
if command -v update-desktop-database &> /dev/null; then
    sudo update-desktop-database /usr/share/applications 2>/dev/null || true
    echo -e "${GREEN}✓ Desktop database updated${NC}"
else
    echo -e "${YELLOW}⚠ update-desktop-database not found (optional)${NC}"
fi

# Clear icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    echo -e "${GREEN}✓ Icon cache updated${NC}"
fi

# Verify uninstallation
echo -e "\n${BOLD}Verifying uninstallation...${NC}"
if command -v svte &> /dev/null; then
    echo -e "${YELLOW}⚠ SVTE still found in PATH${NC}"
    REMAINING_PATH=$(which svte)
    echo -e "  Found at: ${BLUE}$REMAINING_PATH${NC}"
    echo -e "  ${YELLOW}You may need to remove this manually${NC}"
else
    echo -e "${GREEN}✓ SVTE removed from system${NC}"
fi

# Check for config files in home directory
echo -e "\n${BOLD}Checking for user configuration...${NC}"
CONFIG_DIRS=(
    "$HOME/.config/svte"
    "$HOME/.local/share/svte"
)

FOUND_CONFIG=false
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${BLUE}Found config directory:${NC} $dir"
        FOUND_CONFIG=true
    fi
done

if [ "$FOUND_CONFIG" = true ]; then
    echo -e "\n${YELLOW}Would you like to remove user configuration too? (y/n)${NC} "
    read -r config_response
    if [[ "$config_response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        for dir in "${CONFIG_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                rm -rf "$dir"
                echo -e "${GREEN}✓ Removed:${NC} $dir"
            fi
        done
    else
        echo -e "${BLUE}Keeping user configuration${NC}"
    fi
else
    echo -e "${GREEN}✓ No user configuration found${NC}"
fi

# Success message
echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║    Uninstallation successful! 👋       ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════╝${NC}\n"

echo -e "${BOLD}What was removed:${NC}"
for file in "${FOUND_FILES[@]}"; do
    echo -e "  ${GREEN}✓${NC} $file"
done

echo -e "\n${BOLD}Thank you for using SVTE!${NC}"
echo -e "If you want to reinstall, run: ${BLUE}./install.sh${NC}\n"
