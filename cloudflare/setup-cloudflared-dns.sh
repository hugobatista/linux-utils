
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
    echo "This script installs and configures the Cloudflared client to provide"
    echo "DNS over HTTPS (DoH) on a Pi-hole server. It automatically detects system"
    echo "architecture, downloads and installs cloudflared, creates a dedicated user,"
    echo "sets up configuration and systemd service files, and verifies DNS resolution."
    echo ""
    echo "Options:"
    echo "  -h, --help"
    echo "      Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  $0"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${YELLOW}Starting Cloudflared setup...${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    aarch64|arm64)
        CLOUDFLARED_ARCH="arm64"
        ;;
    x86_64|amd64)
        CLOUDFLARED_ARCH="amd64"
        ;;
    armv7l|armhf)
        CLOUDFLARED_ARCH="armhf"
        ;;
    *)
        echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Detected architecture: $ARCH (using cloudflared-linux-$CLOUDFLARED_ARCH)${NC}"
echo ""

# Check if cloudflared is already installed
if command -v cloudflared &> /dev/null; then
    CURRENT_VERSION=$(cloudflared -v 2>&1 | head -n1)
    echo -e "${YELLOW}Cloudflared is already installed: $CURRENT_VERSION${NC}"
    read -p "Do you want to reinstall/update? (yes/no): " reinstall
    if [[ "$reinstall" != "yes" ]]; then
        echo -e "${GREEN}Skipping installation.${NC}"
        exit 0
    fi
    echo ""
fi

# Install cloudflared
echo -e "${YELLOW}Downloading cloudflared...${NC}"
if ! wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CLOUDFLARED_ARCH; then
    echo -e "${RED}Error: Failed to download cloudflared${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing cloudflared...${NC}"
sudo mv -f ./cloudflared-linux-$CLOUDFLARED_ARCH /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared

# Verify installation
if ! command -v cloudflared &> /dev/null; then
    echo -e "${RED}Error: Cloudflared installation failed${NC}"
    exit 1
fi

VERSION=$(cloudflared -v 2>&1 | head -n1)
echo -e "${GREEN}✓ Cloudflared installed successfully: $VERSION${NC}"
echo ""

# Create cloudflared user
echo -e "${YELLOW}Creating cloudflared user...${NC}"
if id "cloudflared" &>/dev/null; then
    echo -e "${GREEN}✓ User 'cloudflared' already exists${NC}"
else
    sudo useradd -s /usr/sbin/nologin -r -M cloudflared
    echo -e "${GREEN}✓ User 'cloudflared' created${NC}"
fi
echo ""

# Create cloudflared config file
echo -e "${YELLOW}Creating cloudflared configuration...${NC}"
sudo tee /etc/default/cloudflared > /dev/null << 'EOF'
# Commandline args for cloudflared, using Cloudflare DNS
CLOUDFLARED_OPTS=--port 5053 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Configuration file created at /etc/default/cloudflared${NC}"
else
    echo -e "${RED}Error: Failed to create configuration file${NC}"
    exit 1
fi
echo ""

# Update permissions
echo -e "${YELLOW}Setting permissions...${NC}"
sudo chown cloudflared:cloudflared /etc/default/cloudflared
sudo chown cloudflared:cloudflared /usr/local/bin/cloudflared
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Create systemd service file
echo -e "${YELLOW}Creating systemd service...${NC}"
sudo tee /etc/systemd/system/cloudflared.service > /dev/null << 'EOF'
[Unit]
Description=cloudflared DNS over HTTPS proxy
After=syslog.target network-online.target

[Service]
Type=simple
User=cloudflared
EnvironmentFile=/etc/default/cloudflared
ExecStart=/usr/local/bin/cloudflared proxy-dns $CLOUDFLARED_OPTS
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Systemd service file created${NC}"
else
    echo -e "${RED}Error: Failed to create systemd service file${NC}"
    exit 1
fi
echo ""

# Enable and start cloudflared service
echo -e "${YELLOW}Enabling and starting cloudflared service...${NC}"
sudo systemctl daemon-reload

if ! sudo systemctl enable cloudflared; then
    echo -e "${RED}Error: Failed to enable cloudflared service${NC}"
    exit 1
fi

if ! sudo systemctl start cloudflared; then
    echo -e "${RED}Error: Failed to start cloudflared service${NC}"
    echo "Service status:"
    sudo systemctl status cloudflared
    exit 1
fi

# Wait a moment for service to fully start
sleep 2

echo -e "${GREEN}✓ Cloudflared service enabled and started${NC}"
echo ""

# Verify cloudflared is running
echo -e "${YELLOW}Verifying cloudflared service...${NC}"
if systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✓ Cloudflared service is running${NC}"
    
    # Test DNS resolution through cloudflared
    echo -e "${YELLOW}Testing DNS resolution...${NC}"
    if command -v dig &> /dev/null; then
        DIG_OUTPUT=$(dig @127.0.0.1 -p 5053 google.com +short 2>&1)
        DIG_EXIT_CODE=$?
        
        if [ $DIG_EXIT_CODE -eq 0 ] && [ -n "$DIG_OUTPUT" ]; then
            echo -e "${GREEN}✓ DNS resolution test successful${NC}"
            echo ""
            echo "DNS Query Result:"
            echo "$DIG_OUTPUT"
        else
            echo -e "${RED}Warning: DNS resolution test failed${NC}"
            echo "The service is running but DNS queries may not be working properly."
            echo ""
            echo "Dig output:"
            echo "$DIG_OUTPUT"
            exit 1
        fi
    else
        echo -e "${YELLOW}Note: 'dig' command not found, skipping DNS resolution test${NC}"
        echo "You can manually test with: dig @127.0.0.1 -p 5053 google.com"
    fi
else
    echo -e "${RED}Error: Cloudflared service failed to start${NC}"
    echo "Please check the status for details:"
    sudo systemctl status cloudflared
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Cloudflared setup completed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Cloudflared is now running on 127.0.0.1:5053"
echo "You can check the status with: systemctl status cloudflared"
echo "View logs with: journalctl -u cloudflared -f"
echo ""
