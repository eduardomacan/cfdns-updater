# Cloudflare DNS Updater

A Bash script that monitors your public IP address and automatically updates a Cloudflare DNS A record when it changes. Designed to run as a systemd service.

## Prerequisites

- Cloudflare account with a domain
- Cloudflare API token with DNS edit permissions
- A Linux system with systemd
- curl

## Install from .deb (Debian/Ubuntu)

```bash
curl -LO https://github.com/eduardomacan/cfdns-updater/releases/latest/download/cfdns-updater_all.deb
sudo apt install ./cfdns-updater_all.deb
sudoedit /etc/cfdns-updater.env   # fill in your values (see below)
sudo systemctl start dns-updater
```

The package installs the script to `/opt/cfdns-updater/`, installs and enables the
`dns-updater` service, and creates `/etc/cfdns-updater.env` from the example if it doesn't
exist. Upgrades keep your config and restart the service.

### Releasing a new version

Bump the version in `VERSION` and push to `main`. A GitHub Action builds the `.deb`
and publishes it as the `v<version>` release. To build locally: `packaging/build-deb.sh`
(output goes to `dist/`).

## Manual Setup

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
| `RETRY_INTERVAL` | `60` | Seconds before retrying after a failed lookup or update |
| `VERIFY_EVERY` | `12` | Compare against the live Cloudflare record every N checks (and on startup) |

## How It Works

1. Fetches current public IP from https://checkip.amazonaws.com and validates it
2. Compares with the last known IP (cached in `/run/cfdns-lastip`, and periodically read from the Cloudflare record itself)
3. If different, updates Cloudflare DNS record via API
4. Caches the new IP only after Cloudflare confirms the update; on any failure it retries after 60 seconds
5. Sleeps for 5 minutes, then repeats (all network calls have timeouts, so the loop can't hang)
6. Handles graceful shutdown on systemd stop/restart

With `--run-once`, the exit code is non-zero if the IP lookup or the update fails.

For reliable updates after a reboot, make sure a network wait-online service is enabled
(`systemd-networkd-wait-online` or `NetworkManager-wait-online`), otherwise
`network-online.target` may be reached before the network is actually usable.

## Uninstall

```bash
sudo systemctl stop dns-updater
sudo systemctl disable dns-updater
sudo rm /etc/systemd/system/dns-updater.service
sudo rm -rf /opt/cfdns-updater
sudo rm /etc/cfdns-updater.env
sudo systemctl daemon-reload
```
