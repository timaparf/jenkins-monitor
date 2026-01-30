#!/bin/bash

# install.sh - Jenkins Resource Monitor Shell Scripts installer
# Must be run as root/sudo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Base paths
INSTALL_DIR="/opt/jenkins-monitor"
DATA_DIR="/var/lib/jenkins-monitor"
LOG_DIR="/var/log/jenkins-monitor"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}Installing Jenkins Resource Monitor...${NC}"

# Function to check if installation was successful
check_step() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ Error: $1${NC}"
        exit 1
    fi
}

# Installing dependencies
echo "Creating directories..."
apt-get update
apt-get install -y gawk sysstat
check_step "Dependencies installed"

# Create directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$LOG_DIR"
check_step "Directories created"

# Copy scripts
echo "Copying scripts..."
cp "$SCRIPT_DIR/scripts/"*.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/"*.sh
check_step "Scripts copied"

# Create systemd service
# echo "Creating systemd service..."
# cat > /etc/systemd/system/jenkins-monitor.service << EOL
# [Unit]
# Description=Jenkins Resource Monitor
# After=jenkins.service

# [Service]
# Type=simple
# User=root
# WorkingDirectory=${DATA_DIR}
# ExecStart=${INSTALL_DIR}/01_jenkins_monitor_to_csv.sh
# Restart=always
# RestartSec=5
# StandardOutput=append:${LOG_DIR}/collector.log
# StandardError=append:${LOG_DIR}/error.log

# [Install]
# WantedBy=multi-user.target
# EOL
# check_step "Systemd service created"

# Create logrotate config
echo "Setting up log rotation..."
cat > /etc/logrotate.d/jenkins-monitor << EOL
${DATA_DIR}/processes.csv {
    daily
    rotate 7
    compress
    missingok
    notifempty
    dateext
    dateformat -%Y%m%d
}
EOL
check_step "Log rotation configured"

# Set permissions
echo "Setting permissions..."
chown -R root:root "$INSTALL_DIR"
chown -R root:root "$DATA_DIR"
chown -R root:root "$LOG_DIR"
chmod 755 "$INSTALL_DIR"
chmod 755 "$DATA_DIR"
chmod 755 "$LOG_DIR"
check_step "Permissions set"

# Start service
# echo "Starting service..."
# systemctl daemon-reload
# systemctl enable jenkins-monitor
# systemctl start jenkins-monitor
# check_step "Service started"

# Test log rotation
logrotate -f /etc/logrotate.d/jenkins-monitor
check_step "Log rotation tested"

nohup ${INSTALL_DIR}/01_jenkins_monitor_to_csv.sh

echo -e "${GREEN}
Installation complete!

Locations:
- Scripts: ${INSTALL_DIR}
- Data: ${DATA_DIR}
- Logs: ${LOG_DIR}

Commands:
- View data: ls -l ${DATA_DIR}
${NC}"
