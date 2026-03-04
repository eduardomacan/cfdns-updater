# Cloudflare DNS Updater

A Bash script that monitors your public IP address and automatically updates a Cloudflare DNS A record when it changes. Designed to run as a systemd service.

## Prerequisites

- Cloudflare account with a domain
- Cloudflare API token with DNS edit permissions
- A Linux system with systemd
- curl

## Setup

### 1. Configure Environment Variables

Copy the example environment file to `/etc/cfdns-updater.env` and fill in your values:

```bash
sudo cp cfdns-updater.env-example /etc/cfdns-updater.env
```

Edit `/etc/cfdns-updater.env` and set:

| Variable | Description |
|----------|-------------|
| `CLOUDFLARE_ZONE_ID` | Your Cloudflare zone ID (found in URL or overview page) |
| `CLOUDFLARE_DNS_RECORD_ID` | The DNS record ID to update |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with `Zone.DNS:Edit` permission |
| `DNS_RECORD` | The full DNS record name (e.g., `home.example.com`) |

### 2. Get Cloudflare IDs

**Zone ID**: Found in Cloudflare Dashboard > Overview (right sidebar)

**DNS Record ID**: Use Cloudflare API:

```bash
curl -s -H "Authorization: Bearer YOUR_API_TOKEN" \
  https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records \
  | jq '.result[] | select(.name=="yourhost.domain.com") | .id'
```

### 3. Install

```bash
sudo mkdir -p /opt/cfdns-updater
sudo cp cfdns-updater /opt/cfdns-updater/
sudo cp dns-updater.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dns-updater
sudo systemctl start dns-updater
```

## Usage

```bash
# Run as daemon (default, runs continuously)
cfdns-updater

# Run once and exit (useful for cron or manual execution)
cfdns-updater --run-once
cfdns-updater -n

# View help
cfdns-updater --help

# View logs
journalctl -u dns-updater -f

# Restart service (e.g., after config changes)
sudo systemctl restart dns-updater

# Stop service
sudo systemctl stop dns-updater
```

## Configuration

Edit `/opt/cfdns-updater/cfdns-updater` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `IP_FILE` | `/run/cfdns-lastip` | File storing last known IP |
| `CHECK_INTERVAL` | `300` | Seconds between IP checks |

## How It Works

1. Fetches current public IP from https://checkip.amazonaws.com
2. Compares with previously stored IP (in `/run/cfdns-lastip`)
3. If different, updates Cloudflare DNS record via API
4. Sleeps for 5 minutes, then repeats
5. Handles graceful shutdown on systemd stop/restart

## Uninstall

```bash
sudo systemctl stop dns-updater
sudo systemctl disable dns-updater
sudo rm /etc/systemd/system/dns-updater.service
sudo rm -rf /opt/cfdns-updater
sudo rm /etc/cfdns-updater.env
sudo systemctl daemon-reload
```
