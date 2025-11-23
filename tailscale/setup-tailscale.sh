#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
# Usage function
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [-y] [-- <tailscale up args>]"
    echo ""
    echo "This script installs and configures Tailscale on your system."
    echo "It passes any arguments after '--' directly to 'tailscale up'."
    echo "It checks for SSH and tag arguments, warns about Tailscale bugs,"
    echo "and helps prevent lockout by prompting for confirmation."
    echo "Run as root or with sudo."
    echo ""
    echo "Options:"
    echo "  -y           Skip confirmation prompts"
    echo "  -h, --help   Show this help message and exit"
    echo "  --           Pass all following arguments to 'tailscale up'"
    echo ""
    echo "Examples:"
    echo "  $0 --"
    echo "  $0 -- --ssh --advertise-tags=tag:example --auth-key=tskey-xxxx"
    echo "  $0 -y -- --ssh"
}

# Parse arguments - everything after '--' will be passed to tailscale up
TS_ARGS=()
SKIP_CONFIRMATION=false

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -y)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --)
            shift
            TS_ARGS=("$@")
            break
            ;;
        *)
            shift
            ;;
    esac
done

# Verify if tailscale is installed
if ! command -v tailscale &> /dev/null
then
    echo -e "${YELLOW}Tailscale not found. Installing Tailscale...${NC}"
    curl -fsSL https://tailscale.com/install.sh | sh
    
    if ! command -v tailscale &> /dev/null; then
        echo -e "${RED}Failed to install Tailscale. Please install manually.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Tailscale installed successfully.${NC}"
fi

# Check if --ssh flag is present in the arguments
SSH_ENABLED=false
for arg in "${TS_ARGS[@]}"; do
    if [[ "$arg" == "--ssh" ]]; then
        SSH_ENABLED=true
        break
    fi
done

# Check if --advertise-tags is present
ADVERTISE_TAGS_PRESENT=false
AUTH_KEY_PRESENT=false
for arg in "${TS_ARGS[@]}"; do
    if [[ "$arg" == --advertise-tags* ]]; then
        ADVERTISE_TAGS_PRESENT=true
    fi
    if [[ "$arg" == --auth-key* ]]; then
        AUTH_KEY_PRESENT=true
    fi
done

# Handle Tailscale bug with --advertise-tags
# https://github.com/tailscale/tailscale/issues/13572
if [ "$ADVERTISE_TAGS_PRESENT" = true ]; then
    if [ "$AUTH_KEY_PRESENT" = false ]; then
        echo -e "${RED}ERROR: --advertise-tags requires --auth-key due to a Tailscale bug.${NC}"
        echo -e "${YELLOW}When using --advertise-tags, Tailscale may force a logout if new tags are added.${NC}"
        echo -e "${YELLOW}To prevent this, you must provide --auth-key along with --advertise-tags.${NC}"
        echo -e "${YELLOW}See: https://github.com/tailscale/tailscale/issues/13572${NC}"
        exit 1
    else
        # Check if required flags are already present
        ACCEPT_RISK_PRESENT=false
        FORCE_REAUTH_PRESENT=false
        for arg in "${TS_ARGS[@]}"; do
            if [[ "$arg" == "--accept-risk=lose-ssh" ]]; then
                ACCEPT_RISK_PRESENT=true
            fi
            if [[ "$arg" == "--force-reauth" ]]; then
                FORCE_REAUTH_PRESENT=true
            fi
        done
        
        # Only warn and ask for confirmation if the user hasn't already provided both flags
        if [ "$ACCEPT_RISK_PRESENT" = false ] || [ "$FORCE_REAUTH_PRESENT" = false ]; then
            echo -e "${YELLOW}WARNING: Detected --advertise-tags with --auth-key.${NC}"
            echo -e "${YELLOW}Due to Tailscale bug #13572, using --advertise-tags may cause a logout if new tags are added.${NC}"
            echo -e "${YELLOW}To handle this, --accept-risk=lose-ssh and --force-reauth will be added to the command.${NC}"
            echo -e "${YELLOW}See: https://github.com/tailscale/tailscale/issues/13572${NC}"
            
            if [ "$SKIP_CONFIRMATION" = false ]; then
                echo ""
                read -p "Do you want to proceed with these additional flags? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${RED}Aborted. Please review your arguments.${NC}"
                    exit 1
                fi
            fi
        fi
        
        # Add the required flags if not already present
        if [ "$ACCEPT_RISK_PRESENT" = false ]; then
            TS_ARGS+=("--accept-risk=lose-ssh")
        fi
        if [ "$FORCE_REAUTH_PRESENT" = false ]; then
            TS_ARGS+=("--force-reauth")
        fi
    fi
fi

# Warn if SSH is not enabled
if [ "$SSH_ENABLED" = false ] && [ "$SKIP_CONFIRMATION" = false ]; then
    echo -e "${RED}WARNING: --ssh flag was not detected in your Tailscale arguments!${NC}"
    echo -e "${YELLOW}Without Tailscale SSH enabled, you may lock yourself out of this machine.${NC}"
    echo -e "${YELLOW}Make sure you have another way to SSH into this machine before proceeding.${NC}"
    echo ""
    read -p "Do you want to continue without SSH? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted. Please add --ssh to your arguments or ensure you have another SSH method.${NC}"
        exit 1
    fi
fi

# Check if sudo is available
if command -v sudo &> /dev/null; then
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
    echo -e "${YELLOW}Note: sudo not available, running commands directly${NC}"
fi

# Run Tailscale up with provided arguments
if [ ${#TS_ARGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Running: ${SUDO_CMD} tailscale up ${TS_ARGS[*]}${NC}"
    ${SUDO_CMD} tailscale up "${TS_ARGS[@]}"
else
    echo -e "${YELLOW}No arguments provided. Authenticating via browser...${NC}"
    ${SUDO_CMD} tailscale up
fi



# Verify Tailscale is running and connected
echo "Checking Tailscale status..."
if ! tailscale status &> /dev/null; then
    echo -e "${RED}Error: Tailscale is not running or not connected${NC}"
    echo -e "${RED}Please ensure Tailscale is up and authenticated before running this script${NC}"
    exit 1
fi



# Get Tailscale status
TS_STATUS=$(tailscale status --json 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Unable to get Tailscale status${NC}"
    exit 1
fi

# Check if Tailscale is connected (Backend state should be "Running")
if ! echo "$TS_STATUS" | grep '"BackendState": "Running"' > /dev/null; then
    echo -e "${RED}Error: Tailscale is not in a running state${NC}"
    echo "Current status:"
    tailscale status
    exit 1
fi

echo -e "${GREEN}✓ Tailscale is running and connected${NC}"
echo ""
