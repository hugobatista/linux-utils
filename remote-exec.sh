#!/bin/bash

# Generic script to deploy and execute scripts on a remote server via SSH
# Supports copying multiple files and passing arguments to the remote script

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Usage function
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 <user@server> <script> [additional_files...] [-- script_args...]"
    echo ""
    echo "This script deploys and executes a script on a remote server via SSH."
    echo "It copies the main script and any additional files to the remote server,"
    echo "then runs the main script with optional arguments."
    echo "Useful for automating remote deployments, configuration, or maintenance."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo ""
    echo "Arguments:"
    echo "  user@server            SSH connection string (e.g., pi@pihole.local)"
    echo "  script                 Main script to execute on remote server"
    echo "  additional_files       Optional files to copy along with the script"
    echo "  script_args            Arguments to pass to the remote script (after --)"
    echo ""
    echo "Examples:"
    echo "  $0 pi@pihole.local setup-static-leases.sh staticleases.conf"
    echo "  $0 pi@pihole.local setup-static-leases.sh staticleases.conf -- -y"
    echo "  $0 root@server.local setup-firewall.sh -- --tcp-ports 80,443 -y"
    echo "  $0 admin@nas.local backup-script.sh config.json data.txt -- --full"
    echo ""
}

# Show usage if not enough arguments or help requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: At least two arguments (user@server and script) are required${NC}"
    echo ""
    usage
    exit 1
fi

SERVER="$1"
shift

MAIN_SCRIPT="$1"
shift

# Check if main script exists
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo -e "${RED}Error: Main script not found at $MAIN_SCRIPT${NC}"
    exit 1
fi

# Collect additional files and script arguments
ADDITIONAL_FILES=()
SCRIPT_ARGS=""
PARSING_ARGS=0

while [[ $# -gt 0 ]]; do
    if [ "$1" == "--" ]; then
        if [ $PARSING_ARGS -eq 0 ]; then
            # First -- encountered: switch to parsing script arguments
            PARSING_ARGS=1
            shift
            continue
        else
            # Subsequent -- should be preserved as part of script arguments
            SCRIPT_ARGS="$SCRIPT_ARGS --"
            shift
            continue
        fi
    fi
    
    if [ $PARSING_ARGS -eq 1 ]; then
        SCRIPT_ARGS="$SCRIPT_ARGS $1"
        shift
    else
        if [ -f "$1" ]; then
            ADDITIONAL_FILES+=("$1")
            shift
        else
            echo -e "${RED}Error: File not found: $1${NC}"
            exit 1
        fi
    fi
done

MAIN_SCRIPT_NAME="$(basename "$MAIN_SCRIPT")"
REMOTE_SCRIPT_PATH="/tmp/$MAIN_SCRIPT_NAME"

echo "========================================"
echo "Remote Script Execution"
echo "========================================"
echo "Server: $SERVER"
echo "Script: $MAIN_SCRIPT_NAME"
if [ ${#ADDITIONAL_FILES[@]} -gt 0 ]; then
    echo "Additional files: ${ADDITIONAL_FILES[*]}"
fi
if [ -n "$SCRIPT_ARGS" ]; then
    echo "Script arguments:$SCRIPT_ARGS"
fi
echo "========================================"
echo "========================================"
echo ""

# Establish SSH control master connection to avoid dual authentication
CONTROL_PATH="/tmp/ssh-control-$$"
echo "Establishing SSH connection..."
ssh -o ControlMaster=auto -o ControlPath="$CONTROL_PATH" -o ControlPersist=60 -fN "$SERVER"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to establish SSH connection${NC}"
    exit 1
fi

# Cleanup function to close the SSH control connection
cleanup_ssh() {
    ssh -O exit -o ControlPath="$CONTROL_PATH" "$SERVER" 2>/dev/null
    rm -f "$CONTROL_PATH"
}
trap cleanup_ssh EXIT

# Copy the main script to the remote server
echo "Step 1: Copying files to remote server..."
scp -o ControlPath="$CONTROL_PATH" "$MAIN_SCRIPT" "$SERVER:$REMOTE_SCRIPT_PATH"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to copy main script to remote server${NC}"
    exit 1
fi

# Copy additional files if any
for file in "${ADDITIONAL_FILES[@]}"; do
    REMOTE_FILE_PATH="/tmp/$(basename "$file")"
    scp -o ControlPath="$CONTROL_PATH" "$file" "$SERVER:$REMOTE_FILE_PATH"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to copy $file to remote server${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Files copied successfully${NC}"
echo ""

# Execute the script on the remote server
echo "Step 2: Executing script on remote server..."
ssh -t -o ControlPath="$CONTROL_PATH" "$SERVER" "chmod +x $REMOTE_SCRIPT_PATH && sudo $REMOTE_SCRIPT_PATH$SCRIPT_ARGS"
EXECUTION_RESULT=$?

if [ $EXECUTION_RESULT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Script execution completed successfully${NC}"
else
    echo ""
    echo -e "${RED}Error: Script execution failed with exit code $EXECUTION_RESULT${NC}"
fi
echo ""

# Clean up the files from the remote server
echo "Cleaning up temporary files on remote server..."
CLEANUP_FILES="$REMOTE_SCRIPT_PATH"
for file in "${ADDITIONAL_FILES[@]}"; do
    CLEANUP_FILES="$CLEANUP_FILES /tmp/$(basename "$file")"
done
ssh -o ControlPath="$CONTROL_PATH" "$SERVER" "rm -f $CLEANUP_FILES"
echo -e "${GREEN}✓ Files removed from remote server${NC}"

echo ""
echo "========================================"
if [ $EXECUTION_RESULT -eq 0 ]; then
    echo -e "${GREEN}Deployment completed successfully!${NC}"
else
    echo -e "${RED}Deployment completed with errors${NC}"
fi
echo "========================================"

exit $EXECUTION_RESULT
