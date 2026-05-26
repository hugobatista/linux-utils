
# linux-utils 🐧

## Overview

This repository provides a collection of Bash and Python utilities for automating server setup, DNS testing, firewall configuration, Pi-hole deployment, and secure networking with Tailscale. Scripts are modular and can be orchestrated together for complex multi-step deployments.

## Main Components

- **run-steps.sh**: Orchestrates multi-step setups by running a series of commands with descriptions, stopping on failure.
- **remote-exec.sh**: Copies scripts/files to a remote server via SSH and executes them, passing arguments as needed.
- **file/copy-file.sh**: Safely copies files to a destination, creating backups if the target exists.
- **iptables/setup-firewall.sh**: Configures IPv4/IPv6 firewall rules, NAT, and port access, with Tailscale support.
- **cloudflare/setup-cloudflared-dns.sh**: Installs and configures Cloudflared for DNS over HTTPS, including systemd service setup.
- **pi-hole/install-pi_hole.sh**: Interactive installer for Pi-hole and PiVPN, with WiFi and driver configuration options.
- **pi-hole/deploy-ftl-config.sh**: Applies Pi-hole configuration from a file, with backup and dry-run support.
- **tailscale/setup-tailscale.sh**: Installs and configures Tailscale, handling SSH and tag arguments safely.
- **dns/dnsflood/dnsflood.sh**: Floods a DNS server with randomized requests for stress/performance testing.
- **dns/TestDnsPerf.py**: Python script to benchmark DNS query performance against multiple servers/domains.

## Folder Structure

- `cloudflare/` — Cloudflared DNS setup script
- `dns/` — DNS flooding and performance scripts
- `file/` — File deployment utility
- `iptables/` — Firewall setup script
- `pi-hole/` — Pi-hole deployment and configuration scripts
- `tailscale/` — Tailscale setup script

## Requirements

- Bash (for all shell scripts)
- Python 3 and dnspython (for TestDnsPerf.py)
- dnsperf (for dnsflood.sh)

## Usage Examples

### Orchestrate setup of multiple servers/services
```bash
./run-steps.sh \
	"Setup Tailscale" \
		"./remote-exec.sh root@mywebserver ./tailscale/setup-tailscale.sh -- -y -- --ssh --advertise-tags=tag:webservers,tag:servers --auth-key=$TAILSCALE_AUTHKEY" \
	"Setup iptables firewall" \
		"./remote-exec.sh root@mywebserver ./setup-firewall.sh -- -y --tcp-ports 80" \
	"Reboot server to apply firewall rules" \
		"ssh root@mywebserver 'sudo reboot' 2>/dev/null || true"
```

### PI-hole configuration with static IP, cloudflared, pihole config
```bash
./run-steps.sh \
	"Configure static IP address" \
		"./remote-exec.sh pi@mypiholeserver ./file/copy-file.sh ./pihole/dhcpcd.conf -- /tmp/dhcpcd.conf /etc/dhcpcd.conf" \
	"Setup Cloudflared DNS over HTTPS" \
		"./remote-exec.sh pi@mypiholeserver ./cloudflare/setup-cloudflared-dns.sh" \
	"Configure Pi-hole settings" \
		"./remote-exec.sh pi@mypiholeserver ./pihole/deploy-ftl-config.sh ./pihole/pihole.conf -- --dry-run" \
	"Setup Tailscale on Pi-hole server" \
		"./remote-exec.sh pi@mypiholeserver ./tailscale/setup-tailscale.sh -- -y -- --advertise-exit-node --accept-dns=false --advertise-routes=192.168.100.0/24 --ssh"
```

### Download and Execute dnsflood.sh Remotely with curl

```bash
curl -O http://go.hugobatista.com/gh/linux-utils/dns/dnsflood/dnsflood.sh
chmod +x dnsflood.sh
./dnsflood.sh 60 192.168.1.1
```

Or, to run it directly without saving:

```bash
curl http://go.hugobatista.com/gh/linux-utils/dns/dnsflood/dnsflood.sh | bash -s -- 60 192.168.1.1
```

## See Also

- Each script includes a usage/help option for details.
- For DNS utilities, see [dns/readme.md](dns/readme.md).
- For Pi-hole and Tailscale, see their respective folders/scripts.


