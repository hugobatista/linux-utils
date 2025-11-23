#!/bin/bash

# Script to configure Pi-hole settings using pihole-FTL CLI
# This script should be run directly on the Pi-hole server

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="/tmp/pihole.conf"
PIHOLE_TOML="/etc/pihole/pihole.toml"


# Usage function
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [options]"
    echo ""
    echo "This script configures Pi-hole settings using the pihole-FTL CLI."
    echo "It parses a configuration file, applies settings, creates a backup,"
    echo "and can run in dry-run mode. Should be run as root on the Pi-hole server."
    echo ""
    echo "The configuration file must be present at /tmp/pihole.conf before running."
    echo "You should copy or upload your config file to /tmp/pihole.conf, for example:"
    echo "  scp pihole.conf user@server:/tmp/pihole.conf"
    echo "or use your deployment script to place it there."
    echo ""
    echo "Options:"
    echo "  -y, --yes      Proceed without confirmation prompt"
    echo "  --dry-run      Show commands that would be executed, but make no changes"
    echo "  -h, --help     Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  $0 --dry-run"
}

YES_FLAG=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            YES_FLAG=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if Pi-hole is installed
if [ ! -d "/etc/pihole" ]; then
    echo -e "${RED}Error: Pi-hole does not appear to be installed on this system${NC}"
    exit 1
fi

# Check if pihole-FTL is available
if ! command -v pihole-FTL &> /dev/null; then
    echo -e "${RED}Error: pihole-FTL command not found${NC}"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file '$CONFIG_FILE' not found${NC}"
    echo "This file should have been uploaded by the deployment script"
    exit 1
fi

echo "========================================"
echo "Pi-hole Configuration Script"
echo "========================================"
echo ""

# Parse the config file and prepare commands
declare -a config_commands=()
declare -a config_display=()

parse_config() {
    local current_key=""
    local array_value=""
    local in_array=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove leading/trailing whitespace using bash parameter expansion
        line="${line#"${line%%[![:space:]]*}"}"  # Remove leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # Remove trailing whitespace
        
        # Skip if line is now empty
        [[ -z "$line" ]] && continue
        
        # Check if line starts a key
        if [[ "$line" =~ ^([a-zA-Z0-9_.]+)=(.*)$ ]]; then
            current_key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Check if it's an array
            if [[ "$value" == "["* ]]; then
                in_array=1
                array_value="$value"
                
                # Check if array closes on same line
                if [[ "$value" == *"]" ]]; then
                    in_array=0
                    config_commands+=("$current_key|$array_value")
                    config_display+=("$current_key=$array_value")
                fi
            else
                # Simple value
                config_commands+=("$current_key|$value")
                config_display+=("$current_key=$value")
            fi
        elif [ $in_array -eq 1 ]; then
            # Continue building array value
            array_value="$array_value$line"
            
            # Check if array closes
            if [[ "$line" == *"]"* ]]; then
                in_array=0
                config_commands+=("$current_key|$array_value")
                config_display+=("$current_key=$array_value")
            fi
        fi
    done < "$CONFIG_FILE"
}

echo "Parsing configuration file..."
parse_config

if [ ${#config_commands[@]} -eq 0 ]; then
    echo -e "${RED}Error: No configuration settings found in $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found ${#config_commands[@]} configuration setting(s)${NC}"
echo ""

echo "========================================"
echo "Configuration settings to be applied:"
echo "========================================"
for display in "${config_display[@]}"; do
    # Truncate long values for display
    if [ ${#display} -gt 80 ]; then
        echo "  ${display:0:77}..."
    else
        echo "  $display"
    fi
done
echo ""

if [ $DRY_RUN -eq 1 ]; then
    echo -e "${BLUE}DRY RUN MODE - No changes will be made${NC}"
    echo ""
    echo "Commands that would be executed:"
    for cmd in "${config_commands[@]}"; do
        IFS='|' read -r key value <<< "$cmd"
        echo "  sudo pihole-FTL --config $key '$value'"
    done
    echo ""
    exit 0
fi

if [ $YES_FLAG -eq 1 ]; then
    echo "Proceeding automatically (--yes flag provided)..."
    confirmation="yes"
else
    read -p "Do you want to apply these configuration settings? (yes/no): " confirmation
fi

if [[ "$confirmation" != "yes" ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

echo ""
echo "Creating backup of current configuration..."
BACKUP_FILE="${PIHOLE_TOML}.backup.$(date +%Y%m%d_%H%M%S)"
cp -p "$PIHOLE_TOML" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
echo ""

echo "Applying configuration settings..."
echo ""

# Track success/failure
success_count=0
failed_count=0
declare -a failed_settings=()

for cmd in "${config_commands[@]}"; do
    # Split key and value
    IFS='|' read -r key value <<< "$cmd"
    
    # Execute the configuration command with key and value as separate arguments
    error_output=$(sudo pihole-FTL --config "$key" "$value" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Applied: $key"
        ((success_count++))
    else
        echo -e "  ${RED}✗${NC} Failed: $key"
        echo -e "    ${RED}Error: $error_output${NC}"
        ((failed_count++))
        failed_settings+=("$key=$value")
    fi
done

echo ""

# Show summary
echo "========================================"
echo "Configuration Summary"
echo "========================================"
echo -e "Successful: ${GREEN}$success_count${NC}"
if [ $failed_count -gt 0 ]; then
    echo -e "Failed: ${RED}$failed_count${NC}"
    echo ""
    echo "Failed settings:"
    for failed in "${failed_settings[@]}"; do
        echo "  - $failed"
    done
fi
echo ""

# Restart Pi-hole DNS service
if [ $success_count -gt 0 ]; then
    echo "Restarting Pi-hole DNS/DHCP service..."
    sudo service pihole-FTL restart

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Pi-hole DNS/DHCP service restarted successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to restart Pi-hole service${NC}"
        echo "You may need to restart it manually with: pihole restartdns"
    fi
fi

echo ""
echo "========================================"
if [ $failed_count -eq 0 ]; then
    echo -e "${GREEN}Configuration completed successfully!${NC}"
else
    echo -e "${YELLOW}Configuration completed with some errors${NC}"
fi
echo "========================================"
echo ""
echo "You can verify the configuration in:"
echo "  - Pi-hole web interface"
echo "  - Configuration file: $PIHOLE_TOML"
echo "  - Backup file: $BACKUP_FILE"
echo ""

exit $failed_count
