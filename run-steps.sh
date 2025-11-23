#!/bin/bash

# Generic script to execute a series of setup steps with descriptions
# Usage: ./run-steps.sh "Step Description 1" "command1" "Step Description 2" "command2" ...
#
# This script executes a series of setup steps, each with a description and command.
# It prints progress, runs each command in order, and stops on failure.
# Useful for automating multi-step deployments, configuration, or maintenance tasks.

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


# Usage function
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 \"Step Description 1\" \"command1\" [\"Step Description 2\" \"command2\" ...]"
    echo ""
    echo "This script executes a series of setup steps, each with a description and command."
    echo "It prints progress, runs each command in order, and stops on failure."
    echo "Useful for automating multi-step deployments, configuration, or maintenance tasks."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  $0 \"
    echo "    \"Setup Tailscale\" \"./remote-exec.sh pi@server ./setup-tailscale.sh -- --ssh\" \"
    echo "    \"Setup Firewall\" \"./remote-exec.sh pi@server ./setup-firewall.sh -- -y\""
}

# Show usage if not enough arguments or help requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: At least one step (description + command) is required${NC}"
    echo ""
    usage
    exit 1
fi

# Check if arguments come in pairs
if [ $((($# % 2))) -ne 0 ]; then
    echo -e "${RED}Error: Arguments must come in pairs (description + command)${NC}"
    echo "Found $# arguments, but expected an even number"
    exit 1
fi

# Store all steps in arrays
STEP_DESCRIPTIONS=()
STEP_COMMANDS=()
STEP_NUMBER=0

while [[ $# -gt 0 ]]; do
    STEP_DESCRIPTIONS+=("$1")
    shift
    STEP_COMMANDS+=("$1")
    shift
    ((STEP_NUMBER++))
done

TOTAL_STEPS=$STEP_NUMBER

# Print header
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}       Multi-Step Setup Script${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Total steps to execute: $TOTAL_STEPS${NC}"
echo ""

# Execute each step
for i in "${!STEP_DESCRIPTIONS[@]}"; do
    STEP_NUM=$((i + 1))
    DESCRIPTION="${STEP_DESCRIPTIONS[$i]}"
    COMMAND="${STEP_COMMANDS[$i]}"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Step $STEP_NUM/$TOTAL_STEPS: $DESCRIPTION${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Executing: $COMMAND${NC}"
    echo ""
    
    # Execute the command
    eval "$COMMAND"
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -ne 0 ]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}✗ Error: Step $STEP_NUM failed with exit code $EXIT_CODE${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${RED}Failed step: $DESCRIPTION${NC}"
        echo -e "${RED}Failed command: $COMMAND${NC}"
        echo ""
        echo -e "${YELLOW}Completed $i out of $TOTAL_STEPS steps before failure${NC}"
        exit $EXIT_CODE
    fi
    
    echo ""
    echo -e "${GREEN}✓ Step $STEP_NUM completed: $DESCRIPTION${NC}"
    echo ""
done

# Print final summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ All $TOTAL_STEPS Steps Completed Successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Summary:"
for i in "${!STEP_DESCRIPTIONS[@]}"; do
    STEP_NUM=$((i + 1))
    echo "  ✓ Step $STEP_NUM: ${STEP_DESCRIPTIONS[$i]}"
done
echo ""
