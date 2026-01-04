# Keepi

Raspberry Pi home server configuration backup. Central control unit for network infrastructure, monitoring, and home automation.

## Services

| Service | Description | Port | URL |
|---------|-------------|------|-----|
| Pi-hole | DNS & ad blocking | 8080 | http://pihole.keepi |
| Unbound | Recursive DNS resolver | 5335 | - |
| Nginx Proxy Manager | Reverse proxy & SSL | 80/443 | http://proxy.keepi |
| Portainer | Container management | 9443 | http://portainer.keepi |
| Homepage | Dashboard | 3000 | http://homepage.keepi |
| Uptime Kuma | Service monitoring | 3001 | http://uptime.keepi |
| Healthchecks | Cron job monitoring | 8000 | http://healthchecks.keepi |
| Speedtest Tracker | Internet speed monitoring | 8765 | http://speedtest.keepi |
| Glances | System monitoring | 61208 | http://glances.keepi |
| What's Up Docker | Container update notifications | 3002 | http://wud.keepi |
| PEC Utilities | Electricity & water tracking | 8050 | http://pec.keepi |

## Network

- **Host IP**: 192.168.0.9
- **DNS**: Pi-hole with Unbound for recursive resolution
- **Reverse Proxy**: Nginx Proxy Manager handles `*.keepi` domains

## Directory Structure

```
~/docker/
├── pihole/          # Pi-hole + Unbound (network_mode: host)
├── nginx-proxy/     # Nginx Proxy Manager
├── portainer/       # Container management
├── homepage/        # Dashboard with service widgets
├── uptime-kuma/     # Uptime monitoring
├── healthchecks/    # Cron job monitoring
├── speedtest-tracker/
├── glances/         # System metrics
├── whatsupdocker/   # Container updates
├── pec-utilities/   # Custom utility tracker
└── wireguard/       # VPN (config only)
```

## Deployment

1. Clone this repo to `~/docker` on the Pi
2. Create a shared network:
   ```bash
   docker network create homelab
   ```
3. Copy your secrets to the appropriate files (see placeholders in compose files)
4. Start services:
   ```bash
   cd ~/docker/<service> && docker compose up -d
   ```

## Backups

Automated backups run via cron using `scripts/backup.sh`:
- Stops containers for consistency
- Creates tarball of all data directories
- Pings Healthchecks on success
- Retains last 7 backups

To restore, extract the backup tarball to `~/docker/`.

## Configuration

Sensitive values are replaced with placeholders:
- `YOUR_PIHOLE_API_KEY` - Generate in Pi-hole admin
- `YOUR_PORTAINER_API_KEY` - Generate in Portainer
- `YOUR_HEALTHCHECKS_API_KEY` - Generate in Healthchecks
- `YOUR_SECRET_KEY_HERE` - Generate with `openssl rand -base64 32`
- `YOUR_APP_KEY_HERE` - Generate with `echo "base64:$(openssl rand -base64 32)"`
