#!/bin/bash
# Backup destination
BACKUP_DIR="$HOME/backups"
DATE=$(date +%Y-%m-%d_%H-%M)
BACKUP_NAME="keepi_backup_$DATE.tar.gz"

# Create backup directory
mkdir -p $BACKUP_DIR

# Stop containers for consistent backup
cd ~/docker/pihole && docker compose stop
cd ~/docker/nginx-proxy && docker compose stop
cd ~/docker/homepage && docker compose stop
cd ~/docker/uptime-kuma && docker compose stop
cd ~/docker/speedtest-tracker && docker compose stop
cd ~/docker/whatsupdocker && docker compose stop
cd ~/docker/healthchecks && docker compose stop
cd ~/docker/glances && docker compose stop
cd ~/docker/pec-utilities && docker compose stop

# Create backup
tar -czvf $BACKUP_DIR/$BACKUP_NAME \
  -C $HOME \
  docker/pihole/etc-pihole \
  docker/pihole/etc-dnsmasq.d \
  docker/nginx-proxy/data \
  docker/nginx-proxy/letsencrypt \
  docker/homepage/config \
  docker/uptime-kuma/data \
  docker/speedtest-tracker/data \
  docker/whatsupdocker/data \
  docker/healthchecks/data \
  docker/pec-utilities/data

# Restart containers
cd ~/docker/pihole && docker compose start
cd ~/docker/nginx-proxy && docker compose start
cd ~/docker/homepage && docker compose start
cd ~/docker/uptime-kuma && docker compose start
cd ~/docker/speedtest-tracker && docker compose start
cd ~/docker/whatsupdocker && docker compose start
cd ~/docker/healthchecks && docker compose start
cd ~/docker/glances && docker compose start
cd ~/docker/pec-utilities && docker compose start

# Ping healthchecks on success
curl -fsS -m 10 --retry 5 http://healthchecks.keepi/ping/YOUR_HEALTHCHECK_UUID > /dev/null

# Keep only last 7 backups
ls -t $BACKUP_DIR/keepi_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo "Backup complete: $BACKUP_DIR/$BACKUP_NAME"
ls -lh $BACKUP_DIR/$BACKUP_NAME
