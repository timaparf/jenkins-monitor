#!/bin/bash

# uninstall.sh - Jenkins Resource Monitor uninstaller
# Must be run as root/sudo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
INSTALL_DIR="/opt/jenkins-monitor"
DATA_DIR="/var/lib/jenkins-monitor"
LOG_DIR="/var/log/jenkins-monitor"
SERVICE_FILE="/etc/systemd/system/jenkins-monitor.service"
LOGROTATE_FILE="/etc/logrotate.d/jenkins-monitor"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}Uninstalling Jenkins Resource Monitor...${NC}"

# Function to check if uninstallation step was successful
check_step() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ Warning: $1 (continuing anyway)${NC}"
    fi
}

# Function to remove a file or directory if it exists
safe_remove() {
    local path=$1
    local description=$2
    if [ -e "$path" ]; then
        rm -rf "$path"
        check_step "Removed $description: $path"
    else
        echo -e "${YELLOW}Skipping: $description not found: $path${NC}"
    fi
}

# Stop service if running
if systemctl is-active --quiet jenkins-monitor; then
    echo "Stopping jenkins-monitor service..."
    systemctl stop jenkins-monitor
    check_step "Service stopped"
else
    echo -e "${YELLOW}Service was not running${NC}"
fi

# Disable service
if systemctl is-enabled --quiet jenkins-monitor 2>/dev/null; then
    echo "Disabling jenkins-monitor service..."
    systemctl disable jenkins-monitor
    check_step "Service disabled"
else
    echo -e "${YELLOW}Service was not enabled${NC}"
fi

# Ask user about data preservation
echo -e "${YELLOW}Data Management:${NC}"
echo "1) Remove everything (scripts, data, and logs)"
echo "2) Keep data and logs, remove only scripts and service files"
echo "3) Cancel uninstallation"
read -p "Please choose an option [1-3]: " -r choice

case $choice in
    1)
        # Remove everything
        echo "Removing all files and directories..."
        safe_remove "$SERVICE_FILE" "Service file"
        safe_remove "$LOGROTATE_FILE" "Logrotate config"
        safe_remove "$INSTALL_DIR" "Installation directory"
        safe_remove "$DATA_DIR" "Data directory"
        safe_remove "$LOG_DIR" "Log directory"
        ;;
    2)
        # Remove only scripts and service files
        echo "Removing service files and scripts, keeping data..."
        safe_remove "$SERVICE_FILE" "Service file"
        safe_remove "$LOGROTATE_FILE" "Logrotate config"
        safe_remove "$INSTALL_DIR" "Installation directory"
        echo -e "${GREEN}Preserved data in: $DATA_DIR${NC}"
        echo -e "${GREEN}Preserved logs in: $LOG_DIR${NC}"
        ;;
    3)
        echo -e "${YELLOW}Uninstallation cancelled${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option. Uninstallation cancelled${NC}"
        exit 1
        ;;
esac

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload
check_step "Systemd reloaded"

echo -e "${GREEN}
Uninstallation complete!

Summary of actions:
- Service stopped and disabled
- Systemd configuration removed
- Logrotate configuration removed
- Scripts removed from $INSTALL_DIR"

if [ "$choice" == "1" ]; then
    echo "- All data and logs removed"
else
    echo "- Data and logs preserved in:
  * $DATA_DIR
  * $LOG_DIR"
fi

echo -e "${NC}"

# Final note about manual cleanup if needed
if [ "$choice" == "2" ]; then
    echo -e "${YELLOW}Note: To manually remove data later, use:
    sudo rm -rf $DATA_DIR
    sudo rm -rf $LOG_DIR${NC}"
fi
