#!/bin/bash

# Script to deploy a file to a specific destination with backup
# This script should be run directly on the target server

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi


# Usage function
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 <source_file> <destination_path>"
    echo ""
    echo "This script deploys a file to a specific destination with backup."
    echo "It should be run directly on the target server and must be executed as root."
    echo "If the destination file exists, a timestamped backup is created before copying."
    echo ""
    echo "Options:"
    echo "  -h, --help"
    echo "      Show this help message and exit"
    echo ""
    echo "Examples:"
    echo "  $0 ./dhcpcd.conf /etc/dhcpcd.conf"
    echo "  $0 ./config.txt /boot/config.txt"
}

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

SOURCE_FILE="$1"
DESTINATION="$2"

echo ""
echo -e "${YELLOW}Deploying file to destination${NC}"
echo -e "${YELLOW}Source: $SOURCE_FILE${NC}"
echo -e "${YELLOW}Destination: $DESTINATION${NC}"
echo ""

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}Error: Source file not found: $SOURCE_FILE${NC}"
    exit 1
fi

# Create backup of existing destination file if it exists
if [ -f "$DESTINATION" ]; then
    BACKUP_FILE="${DESTINATION}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}Creating backup of existing file...${NC}"
    cp -p "$DESTINATION" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}No existing file found at destination, creating new file${NC}"
fi

# Copy the file to destination
echo -e "${YELLOW}Copying file to $DESTINATION...${NC}"
if cp "$SOURCE_FILE" "$DESTINATION"; then
    echo -e "${GREEN}✓ File deployed successfully${NC}"
else
    echo -e "${RED}Error: Failed to copy file to destination${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ File deployment completed${NC}"
echo ""
