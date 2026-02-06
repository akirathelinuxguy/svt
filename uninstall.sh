#!/bin/bash
# SVTE Terminal Emulator - Final Uninstaller
set -euo pipefail

# --- Configuration ---
BACKUP_DIR="/tmp/svte-backup-$(date +%Y%m%d-%H%M%S)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/svte"
BINARY_PATHS=("/usr/local/bin/svte" "/usr/bin/svte" "$HOME/.local/bin/svte")
DESKTOP_PATH="$HOME/.local/share/applications/svte.desktop"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}SVTE Uninstaller v2.0${NC}\n"

# 1. Kill running instances to prevent file-locking issues
if pgrep -x svte > /dev/null; then
    echo -e "${BLUE}ℹ Closing running SVTE instances...${NC}"
    pkill -TERM svte || true
    sleep 1
fi

# 2. Backup Config (Fixed logic to prevent hanging)
if [ -d "$CONFIG_DIR" ]; then
    echo -e "${BLUE}ℹ Creating backup of configuration...${NC}"
    mkdir -p "$BACKUP_DIR"
    # Using cp -r on the direct path is fast and won't hang
    if cp -r "$CONFIG_DIR" "$BACKUP_DIR/" 2>/dev/null; then
        echo -e "${GREEN}✓ Backup saved to: $BACKUP_DIR${NC}"
    else
        echo -e "${RED}✗ Backup failed, skipping...${NC}"
    fi
fi

# 3. Remove Binary
echo -e "${BLUE}ℹ Removing binary files...${NC}"
for path in "${BINARY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        if [ -w "$path" ]; then
            rm "$path" && echo -e "${GREEN}✓ Removed $path${NC}"
        else
            echo -e "${BLUE}ℹ Requesting sudo to remove $path${NC}"
            sudo rm "$path" && echo -e "${GREEN}✓ Removed $path${NC}"
        fi
    fi
done

# 4. Remove Desktop Entry
if [ -f "$DESKTOP_PATH" ]; then
    rm "$DESKTOP_PATH"
    echo -e "${GREEN}✓ Removed desktop entry${NC}"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# 5. Remove Config
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    echo -e "${GREEN}✓ Removed configuration directory${NC}"
fi

echo -e "\n${BOLD}${GREEN}Uninstallation Complete!${NC}"