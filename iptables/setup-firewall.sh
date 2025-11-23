#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Usage function
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [options]"
    echo ""
    echo "This script configures a secure firewall using iptables and ip6tables."
    echo "It sets up IPv4 and IPv6 rules, allows you to specify allowed TCP ports,"
    echo "optionally disables ICMP (ping), and saves rules for persistence."
    echo "It also configures NAT masquerading for Tailscale-marked packets."
    echo ""
    echo "Options:"
    echo "  -y, --yes              Proceed without confirmation prompt"
    echo "  --tcp-ports PORTS      Comma-separated list of TCP ports to allow (e.g. 22,80,443)"
    echo "  --disable-icmp         Block incoming ICMP (ping) requests"
    echo "  -h, --help             Show this help message and exit"
    echo ""
    echo "Examples:"
    echo "  $0 --tcp-ports 22,80,443"
    echo "  $0 -y --disable-icmp"
}

YES_FLAG=0
TCP_PORTS=()
DISABLE_ICMP=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            YES_FLAG=1
            shift
            ;;
        --tcp-ports)
            IFS=',' read -ra TCP_PORTS <<< "$2"
            shift 2
            ;;
        --disable-icmp)
            DISABLE_ICMP=1
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



# Install iptables-persistent if not already installed
apt install -y iptables-persistent

# Ensure the service is enabled to load rules on boot
systemctl enable netfilter-persistent


echo "========================================"
echo "Current IPv4 iptables rules:"
echo "========================================"
iptables -L -v -n --line-numbers
echo ""
echo "========================================"
echo "Current IPv4 NAT table:"
echo "========================================"
iptables -t nat -L -v -n --line-numbers
echo ""
echo "========================================"
echo "Current IPv6 ip6tables rules:"
echo "========================================"
ip6tables -L -v -n --line-numbers
echo ""

if [ $YES_FLAG -eq 1 ]; then
    echo "Proceeding automatically (--yes flag provided)..."
    confirmation="yes"
else
    # Warn if no TCP ports are specified
    if [ ${#TCP_PORTS[@]} -eq 0 ]; then
        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                        ⚠️  WARNING  ⚠️                         ║${NC}"
        echo -e "${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║  No TCP ports specified! All incoming TCP traffic will be     ║${NC}"
        echo -e "${RED}║  BLOCKED, including SSH (port 22).                            ║${NC}"
        echo -e "${RED}║                                                               ║${NC}"
        echo -e "${RED}║  You will ONLY be able to access this server via Tailscale.  ║${NC}"
        echo -e "${RED}║                                                               ║${NC}"
        echo -e "${RED}║  If Tailscale is not properly configured, you may LOSE       ║${NC}"
        echo -e "${RED}║  ACCESS to this server!                                      ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Make sure Tailscale is working before proceeding!${NC}"
        echo ""
    fi
    
    read -p "Do you want to continue and replace these rules? (yes/no): " confirmation
fi

if [[ "$confirmation" != "yes" ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

echo ""
echo "Proceeding with firewall setup..."
echo ""

##### IPv6 Firewall Setup - Disable IPv6 Traffic #####
# Flush existing rules and set default policies for the filter table
ip6tables -F
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

# Set up the mangle table (default policy is ACCEPT)
ip6tables -t mangle -F
ip6tables -t mangle -P PREROUTING ACCEPT
ip6tables -t mangle -P INPUT ACCEPT
ip6tables -t mangle -P FORWARD ACCEPT
ip6tables -t mangle -P OUTPUT ACCEPT
ip6tables -t mangle -P POSTROUTING ACCEPT

# Set up the nat table (default policy is ACCEPT)
ip6tables -t nat -F
ip6tables -t nat -P PREROUTING ACCEPT
ip6tables -t nat -P INPUT ACCEPT
ip6tables -t nat -P OUTPUT ACCEPT
ip6tables -t nat -P POSTROUTING ACCEPT

# Save the rules to a file
ip6tables-save > /etc/iptables/rules.v6


##### IPv4 Firewall Setup - allow icmp and http 80 #####

# Flush existing rules and set default policies
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Allow all loopback (lo) traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow incoming ICMP echo-request (ping) unless disabled
if [ $DISABLE_ICMP -eq 0 ]; then
    iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT
    echo -e "${GREEN}✓ ICMP (ping) allowed${NC}"
else
    echo -e "${YELLOW}✗ ICMP (ping) disabled${NC}"
fi

# Allow established and related incoming connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow specified TCP ports
if [ ${#TCP_PORTS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Allowing incoming TCP ports: ${TCP_PORTS[*]}${NC}"
    for port in "${TCP_PORTS[@]}"; do
        # Validate port is a number
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            echo -e "${GREEN}✓ Allowed TCP port $port${NC}"
        else
            echo -e "${RED}Warning: Invalid port number '$port' - skipping${NC}"
        fi
    done
else
    echo -e "${YELLOW}No TCP ports specified - all incoming TCP traffic will be blocked${NC}"
fi
echo ""

# NAT table: create ts-postrouting chain and masquerade marked packets
iptables -t nat -N ts-postrouting
iptables -t nat -A POSTROUTING -j ts-postrouting
iptables -t nat -A ts-postrouting -m mark --mark 0x40000/0xff0000 -j MASQUERADE

# Save the rules
iptables-save > /etc/iptables/rules.v4