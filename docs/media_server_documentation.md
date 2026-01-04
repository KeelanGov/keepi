# Media Server Configuration Documentation

**Last Updated:** December 2025

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Hardware Specifications](#hardware-specifications)
3. [Network Topology](#network-topology)
4. [Service Descriptions](#service-descriptions)
5. [Storage Architecture](#storage-architecture)
6. [Service URLs](#service-urls)
7. [Docker Compose Configurations](#docker-compose-configurations)
8. [Setup Instructions](#setup-instructions)
9. [Jellyfin Configuration](#jellyfin-configuration)
10. [Automation Stack Configuration](#automation-stack-configuration)
11. [Storage Tiering](#storage-tiering)
12. [Multi-Client Streaming](#multi-client-streaming)
13. [Backup Strategy](#backup-strategy)
14. [Troubleshooting](#troubleshooting)
15. [Useful Commands](#useful-commands)

---

## Architecture Overview

This setup uses a distributed architecture with two main devices:

- **Raspberry Pi 5 (keepi)** — Network gateway, DNS, reverse proxy, request management
- **Media Server (PC)** — Streaming, transcoding, automation, storage

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              NETWORK                                     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    RASPBERRY PI 5 (keepi)                          │  │
│  │                    192.168.0.9                                     │  │
│  │                                                                    │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────────────┐ │  │
│  │  │ Pi-hole  │ │   NPM    │ │ Tailscale│ │      Jellyseerr        │ │  │
│  │  │   DNS    │ │  Proxy   │ │   VPN    │ │  Request Management    │ │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────────────────────┘ │  │
│  │                                                                    │  │
│  │  ┌──────────┐ ┌──────────┐                                         │  │
│  │  │ Homepage │ │  Uptime  │                                         │  │
│  │  │Dashboard │ │   Kuma   │                                         │  │
│  │  └──────────┘ └──────────┘                                         │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                    │                                     │
│                                    │ Proxies requests                    │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    MEDIA SERVER (PC)                               │  │
│  │                    192.168.0.50                                    │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐  │  │
│  │  │                      STREAMING                               │  │  │
│  │  │  ┌────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │                    JELLYFIN                            │  │  │  │
│  │  │  │  • Library management                                  │  │  │  │
│  │  │  │  • Hardware transcoding (NVENC)                        │  │  │  │
│  │  │  │  • Multi-client streaming                              │  │  │  │
│  │  │  └────────────────────────────────────────────────────────┘  │  │  │
│  │  └──────────────────────────────────────────────────────────────┘  │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐  │  │
│  │  │                    AUTOMATION                                │  │  │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────────────┐ │  │  │
│  │  │  │ Radarr  │ │ Sonarr  │ │Prowlarr │ │    qBittorrent      │ │  │  │
│  │  │  │ Movies  │ │TV Shows │ │Indexers │ │     Downloads       │ │  │  │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────────────────────┘  │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐  │  │
│  │  │                      STORAGE                                 │  │  │
│  │  │  ┌────────────────────┐    ┌────────────────────────────┐    │  │  │
│  │  │  │   HOT (SSD)        │    │       COLD (HDD)           │    │  │  │
│  │  │  │   /mnt/hot         │    │       /mnt/cold            │    │  │  │
│  │  │  │   500GB - 1TB      │    │       4TB - 8TB            │    │  │  │
│  │  │  └────────────────────┘    └────────────────────────────┘    │  │  │
│  │  └──────────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                    │                                     │
│                                    ▼                                     │
│                               CLIENTS                                    │
│                    TV / Phone / Laptop / Tablet                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Hardware Specifications

### Raspberry Pi 5 (keepi)

| Component | Specification |
|-----------|---------------|
| Hostname | keepi |
| Username | keelan |
| Local IP | 192.168.0.9 |
| OS | Raspberry Pi OS Lite (64-bit) - Bookworm |
| Hardware | Raspberry Pi 5 4GB |
| Storage | SD Card |
| Network | WiFi (wlan0) |
| Timezone | Africa/Johannesburg (SAST) |

### Media Server (PC)

| Component | Specification |
|-----------|---------------|
| Hostname | mediaserver (suggested) |
| Local IP | 192.168.0.50 (example) |
| CPU | Intel i7 (with Quick Sync) |
| GPU | NVIDIA GTX 1070 Ti (NVENC) |
| OS | Ubuntu Server 24.04 LTS (recommended) |
| Hot Storage | SSD (500GB - 1TB) |
| Cold Storage | HDD (4TB - 8TB) |

#### Transcoding Capacity

| Scenario | Capacity |
|----------|----------|
| Direct plays | Unlimited |
| 1080p transcodes (NVENC) | 8-10 simultaneous |
| 4K → 1080p transcodes | 3-4 simultaneous |
| 4K HDR → SDR tone mapping | 2-3 simultaneous |

---

## Network Topology

### Request Flow

```
1. Client requests jellyfin.keepi
              │
              ▼
2. Pi-hole resolves jellyfin.keepi → 192.168.0.9
              │
              ▼
3. NPM receives request on port 80
   Routes to media server 192.168.0.50:8096
              │
              ▼
4. Jellyfin serves stream directly to client
   (transcoding happens on media server if needed)
```

### Remote Access (Tailscale)

```
Remote client connects to Tailscale
              │
              ▼
Assigned IP in Tailscale network (100.x.x.x)
              │
              ▼
Can access jellyfin.keepi as if on local network
              │
              ▼
Traffic routes through Pi → Media Server
```

---

## Service Descriptions

### On Raspberry Pi (keepi)

| Service | Purpose | Description |
|---------|---------|-------------|
| **Pi-hole** | DNS Server | Resolves `*.keepi` domains to local IPs. Blocks ads network-wide. |
| **Nginx Proxy Manager** | Reverse Proxy | Single entry point for all services. Routes requests to correct backend. |
| **Tailscale** | VPN | Zero-config mesh VPN for secure remote access. Replaces WireGuard. |
| **Jellyseerr** | Request Management | Netflix-like interface for users to request movies/shows. |
| **Homepage** | Dashboard | Central dashboard displaying all services and system status. |
| **Uptime Kuma** | Monitoring | Monitors all services and alerts on downtime. |

### On Media Server

| Service | Purpose | Description |
|---------|---------|-------------|
| **Jellyfin** | Media Streaming | Core media server. Manages library, serves streams, handles transcoding. |
| **Radarr** | Movie Automation | Monitors for wanted movies, searches, downloads, organises. |
| **Sonarr** | TV Automation | Monitors for TV episodes, searches, downloads, organises. |
| **Prowlarr** | Indexer Management | Centralised indexer configuration. Syncs to Radarr/Sonarr. |
| **qBittorrent** | Download Client | Handles actual file downloads. Controlled by Radarr/Sonarr. |

---

## Storage Architecture

### Tiered Storage Model

| Tier | Type | Mount Point | Size | Purpose |
|------|------|-------------|------|---------|
| Hot | SSD | `/mnt/hot` | 500GB - 1TB | Currently watching, recently added, favourites |
| Cold | HDD | `/mnt/cold` | 4TB - 8TB | Archive, watched 90+ days ago |

### Directory Structure

```
/mnt/hot/
├── movies/
│   └── Movie Name (Year)/
│       └── Movie Name (Year).mkv
├── tv/
│   └── Show Name/
│       └── Season 01/
│           └── Show Name S01E01.mkv
└── downloads/
    └── complete/

/mnt/cold/
├── movies/
│   └── [Archived movies with same structure]
└── tv/
    └── [Archived TV shows with same structure]
```

### Jellyfin Library Configuration

Jellyfin scans both locations as a single library:

| Library | Paths |
|---------|-------|
| Movies | `/mnt/hot/movies`, `/mnt/cold/movies` |
| TV Shows | `/mnt/hot/tv`, `/mnt/cold/tv` |

### Storage Migration Logic

Content moves from hot to cold based on watch history:

```
For each media file:
    If last_watched > 90 days AND location == /mnt/hot:
        Move to /mnt/cold
        Trigger Jellyfin library scan
```

---

## Service URLs

### Primary URLs (via reverse proxy)

| Service | URL | Backend |
|---------|-----|---------|
| Dashboard | http://dash.keepi | Pi: 3000 |
| Pi-hole | http://pihole.keepi/admin | Pi: 8080 |
| Portainer | http://portainer.keepi | Pi: 9443 |
| Uptime Kuma | http://uptime.keepi | Pi: 3001 |
| NPM Admin | http://proxy.keepi | Pi: 81 |
| Requests | http://requests.keepi | Pi: 5055 |
| Jellyfin | http://jellyfin.keepi | Media Server: 8096 |
| Radarr | http://radarr.keepi | Media Server: 7878 |
| Sonarr | http://sonarr.keepi | Media Server: 8989 |
| Prowlarr | http://prowlarr.keepi | Media Server: 9696 |
| Downloads | http://downloads.keepi | Media Server: 8080 |

### DNS Records (Pi-hole)

Add these in Pi-hole → Local DNS → DNS Records:

| Domain | IP Address |
|--------|------------|
| dash.keepi | 192.168.0.9 |
| pihole.keepi | 192.168.0.9 |
| portainer.keepi | 192.168.0.9 |
| uptime.keepi | 192.168.0.9 |
| proxy.keepi | 192.168.0.9 |
| requests.keepi | 192.168.0.9 |
| jellyfin.keepi | 192.168.0.9 |
| radarr.keepi | 192.168.0.9 |
| sonarr.keepi | 192.168.0.9 |
| prowlarr.keepi | 192.168.0.9 |
| downloads.keepi | 192.168.0.9 |

### NPM Proxy Hosts

| Domain | Scheme | Forward IP | Port |
|--------|--------|------------|------|
| jellyfin.keepi | http | 192.168.0.50 | 8096 |
| radarr.keepi | http | 192.168.0.50 | 7878 |
| sonarr.keepi | http | 192.168.0.50 | 8989 |
| prowlarr.keepi | http | 192.168.0.50 | 9696 |
| downloads.keepi | http | 192.168.0.50 | 8080 |
| requests.keepi | http | 192.168.0.9 | 5055 |

---

## Docker Compose Configurations

### Raspberry Pi Services

#### Jellyseerr

*File: `~/docker/jellyseerr/docker-compose.yml`*

```yaml
services:
  jellyseerr:
    container_name: jellyseerr
    image: fallenbagel/jellyseerr:latest
    restart: unless-stopped
    ports:
      - '5055:5055'
    volumes:
      - ./config:/app/config
    environment:
      TZ: Africa/Johannesburg
    networks:
      - homelab

networks:
  homelab:
    external: true
```

### Media Server Services

#### Jellyfin

*File: `~/docker/jellyfin/docker-compose.yml`*

```yaml
services:
  jellyfin:
    container_name: jellyfin
    image: jellyfin/jellyfin:latest
    restart: unless-stopped
    ports:
      - '8096:8096'
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /mnt/hot:/media/hot:ro
      - /mnt/cold:/media/cold:ro
    environment:
      TZ: Africa/Johannesburg
    devices:
      - /dev/dri:/dev/dri                    # Intel Quick Sync
    runtime: nvidia                           # NVIDIA GPU
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    networks:
      - mediaserver

networks:
  mediaserver:
    driver: bridge
```

#### Radarr

*File: `~/docker/radarr/docker-compose.yml`*

```yaml
services:
  radarr:
    container_name: radarr
    image: linuxserver/radarr:latest
    restart: unless-stopped
    ports:
      - '7878:7878'
    volumes:
      - ./config:/config
      - /mnt/hot:/media/hot
      - /mnt/cold:/media/cold
      - /mnt/hot/downloads:/downloads
    environment:
      TZ: Africa/Johannesburg
      PUID: 1000
      PGID: 1000
    networks:
      - mediaserver

networks:
  mediaserver:
    external: true
```

#### Sonarr

*File: `~/docker/sonarr/docker-compose.yml`*

```yaml
services:
  sonarr:
    container_name: sonarr
    image: linuxserver/sonarr:latest
    restart: unless-stopped
    ports:
      - '8989:8989'
    volumes:
      - ./config:/config
      - /mnt/hot:/media/hot
      - /mnt/cold:/media/cold
      - /mnt/hot/downloads:/downloads
    environment:
      TZ: Africa/Johannesburg
      PUID: 1000
      PGID: 1000
    networks:
      - mediaserver

networks:
  mediaserver:
    external: true
```

#### Prowlarr

*File: `~/docker/prowlarr/docker-compose.yml`*

```yaml
services:
  prowlarr:
    container_name: prowlarr
    image: linuxserver/prowlarr:latest
    restart: unless-stopped
    ports:
      - '9696:9696'
    volumes:
      - ./config:/config
    environment:
      TZ: Africa/Johannesburg
      PUID: 1000
      PGID: 1000
    networks:
      - mediaserver

networks:
  mediaserver:
    external: true
```

#### qBittorrent

*File: `~/docker/qbittorrent/docker-compose.yml`*

```yaml
services:
  qbittorrent:
    container_name: qbittorrent
    image: linuxserver/qbittorrent:latest
    restart: unless-stopped
    ports:
      - '8080:8080'
      - '6881:6881'
      - '6881:6881/udp'
    volumes:
      - ./config:/config
      - /mnt/hot/downloads:/downloads
    environment:
      TZ: Africa/Johannesburg
      PUID: 1000
      PGID: 1000
      WEBUI_PORT: 8080
    networks:
      - mediaserver

networks:
  mediaserver:
    external: true
```

---

## Setup Instructions

### Phase 1: Media Server Base Setup

1. **Install Ubuntu Server 24.04 LTS**

2. **Install Docker**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```

3. **Install NVIDIA Container Toolkit**
   ```bash
   # Add NVIDIA repository
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   
   # Install
   sudo apt update
   sudo apt install -y nvidia-container-toolkit
   sudo systemctl restart docker
   ```

4. **Create Docker network**
   ```bash
   docker network create mediaserver
   ```

5. **Create directory structure**
   ```bash
   mkdir -p ~/docker/{jellyfin,radarr,sonarr,prowlarr,qbittorrent}
   ```

6. **Mount storage drives**
   ```bash
   # Identify drives
   lsblk
   
   # Create mount points
   sudo mkdir -p /mnt/hot /mnt/cold
   
   # Add to /etc/fstab (example - use your UUIDs)
   # UUID=xxxx-xxxx /mnt/hot ext4 defaults 0 2
   # UUID=yyyy-yyyy /mnt/cold ext4 defaults,noatime 0 2
   
   # Mount
   sudo mount -a
   ```

7. **Create media directories**
   ```bash
   sudo mkdir -p /mnt/hot/{movies,tv,downloads/complete}
   sudo mkdir -p /mnt/cold/{movies,tv}
   sudo chown -R $USER:$USER /mnt/hot /mnt/cold
   ```

### Phase 2: Deploy Services

1. **Deploy Jellyfin**
   ```bash
   cd ~/docker/jellyfin
   # Create docker-compose.yml as shown above
   docker compose up -d
   ```

2. **Deploy automation stack**
   ```bash
   cd ~/docker/radarr && docker compose up -d
   cd ~/docker/sonarr && docker compose up -d
   cd ~/docker/prowlarr && docker compose up -d
   cd ~/docker/qbittorrent && docker compose up -d
   ```

### Phase 3: Connect to Pi

1. **Add DNS records in Pi-hole**
   - Navigate to Pi-hole → Local DNS → DNS Records
   - Add all media server domains pointing to 192.168.0.9

2. **Add proxy hosts in NPM**
   - Navigate to NPM → Proxy Hosts → Add
   - Add entries for each media server service

3. **Deploy Jellyseerr on Pi**
   ```bash
   cd ~/docker/jellyseerr
   docker compose up -d
   ```

### Phase 4: Configure Tailscale

1. **Install Tailscale on Pi**
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

2. **Install Tailscale on Media Server**
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

3. **Enable subnet routing (optional)**
   ```bash
   # On Pi - advertise local network
   sudo tailscale up --advertise-routes=192.168.0.0/24
   ```

---

## Jellyfin Configuration

### Enable Hardware Transcoding

1. Navigate to Dashboard → Playback → Transcoding

2. **Hardware acceleration:** NVIDIA NVENC

3. **Enable hardware decoding for:**
   - ☑ H.264
   - ☑ HEVC
   - ☑ MPEG2
   - ☑ VC1
   - ☑ VP8
   - ☑ VP9

4. **Enable hardware encoding**

5. **Enable tone mapping** (for HDR → SDR conversion)

### Library Setup

1. Navigate to Dashboard → Libraries → Add Media Library

2. **Movies:**
   - Content type: Movies
   - Folders: `/media/hot/movies`, `/media/cold/movies`

3. **TV Shows:**
   - Content type: Shows
   - Folders: `/media/hot/tv`, `/media/cold/tv`

### User Configuration

- Create separate user accounts for family members
- Set parental controls per user if needed
- Configure remote access bandwidth limits

---

## Automation Stack Configuration

### Connection Flow

```
Jellyseerr → Radarr/Sonarr → Prowlarr → Indexers
                  ↓
            qBittorrent
                  ↓
            Download completes
                  ↓
            Radarr/Sonarr moves & renames
                  ↓
            Jellyfin scans library
```

### Prowlarr Setup

1. Add indexers (search sources)
2. Add applications:
   - Radarr: `http://radarr:7878`
   - Sonarr: `http://sonarr:8989`
3. Sync indexers to applications

### Radarr Setup

1. Settings → Media Management
   - Root folder: `/media/hot/movies`
   - Enable rename movies
   
2. Settings → Download Clients
   - Add qBittorrent: `http://qbittorrent:8080`

3. Settings → Connect
   - Add Jellyfin notification

### Sonarr Setup

1. Settings → Media Management
   - Root folder: `/media/hot/tv`
   - Enable rename episodes

2. Settings → Download Clients
   - Add qBittorrent: `http://qbittorrent:8080`

3. Settings → Connect
   - Add Jellyfin notification

### Jellyseerr Setup

1. Connect to Jellyfin server
2. Add Radarr server
3. Add Sonarr server
4. Configure user permissions

---

## Storage Tiering

### Automated Tiering Script

*File: `~/scripts/media-tier.sh`*

```bash
#!/bin/bash

# Configuration
HOT_PATH="/mnt/hot"
COLD_PATH="/mnt/cold"
JELLYFIN_API="http://localhost:8096"
JELLYFIN_API_KEY="your-api-key-here"
DAYS_THRESHOLD=90

# Get current date
NOW=$(date +%s)
THRESHOLD=$((NOW - (DAYS_THRESHOLD * 86400)))

# Function to get last played date from Jellyfin
get_last_played() {
    local item_id=$1
    curl -s "${JELLYFIN_API}/Items/${item_id}?api_key=${JELLYFIN_API_KEY}" | \
        jq -r '.UserData.LastPlayedDate // empty'
}

# Function to move media
move_to_cold() {
    local source=$1
    local dest="${COLD_PATH}${source#$HOT_PATH}"
    local dest_dir=$(dirname "$dest")
    
    mkdir -p "$dest_dir"
    mv "$source" "$dest"
    echo "Moved: $source → $dest"
}

# Find and process files
find "$HOT_PATH" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) | while read file; do
    # Get file's last access time as fallback
    last_access=$(stat -c %X "$file")
    
    if [ "$last_access" -lt "$THRESHOLD" ]; then
        move_to_cold "$file"
    fi
done

# Trigger Jellyfin library scan
curl -X POST "${JELLYFIN_API}/Library/Refresh?api_key=${JELLYFIN_API_KEY}"

echo "Tiering complete. Library scan triggered."
```

### Cron Job

```bash
# Run weekly on Sunday at 4am
0 4 * * 0 /home/user/scripts/media-tier.sh >> /home/user/logs/tiering.log 2>&1
```

### HDD Spin-Down Configuration

```bash
# Install hdparm
sudo apt install hdparm

# Configure spin-down after 20 minutes (value 240 = 20 min)
sudo hdparm -S 240 /dev/sdb

# Make persistent - add to /etc/hdparm.conf
/dev/sdb {
    spindown_time = 240
}
```

---

## Multi-Client Streaming

### Playback Modes

| Mode | CPU Usage | When It Occurs |
|------|-----------|----------------|
| Direct Play | ~0% | Client supports exact format |
| Direct Stream | ~5% | Container remux needed (MKV→MP4) |
| Transcode | 30-100%+ | Codec conversion or bandwidth limit |

### Decision Flow

```
Client requests playback
         │
         ▼
Does client support video codec?
         │
    ┌────┴────┐
   Yes       No
    │         │
    ▼         ▼
Container   TRANSCODE
supported?
    │
┌───┴───┐
Yes    No
│       │
▼       ▼
DIRECT  DIRECT
PLAY    STREAM
```

### Optimising for Direct Play

Store media in widely compatible formats:

| Format | Compatibility |
|--------|---------------|
| H.264 + AAC in MP4 | Universal |
| H.264 + AAC in MKV | Most devices |
| HEVC (H.265) | Modern devices |
| 4K HEVC HDR | Smart TVs, Apple TV, Shield |

---

## Backup Strategy

### What to Backup

| Service | Config Location | Priority |
|---------|-----------------|----------|
| Jellyfin | `~/docker/jellyfin/config` | High |
| Radarr | `~/docker/radarr/config` | High |
| Sonarr | `~/docker/sonarr/config` | High |
| Prowlarr | `~/docker/prowlarr/config` | Medium |
| qBittorrent | `~/docker/qbittorrent/config` | Low |

### Backup Script

*File: `~/backup-media-server.sh`*

```bash
#!/bin/bash

BACKUP_DIR="$HOME/backups"
DATE=$(date +%Y-%m-%d_%H-%M)
BACKUP_NAME="mediaserver_backup_$DATE.tar.gz"

mkdir -p $BACKUP_DIR

# Stop containers for consistent backup
docker compose -f ~/docker/jellyfin/docker-compose.yml stop
docker compose -f ~/docker/radarr/docker-compose.yml stop
docker compose -f ~/docker/sonarr/docker-compose.yml stop
docker compose -f ~/docker/prowlarr/docker-compose.yml stop

# Create backup
tar -czvf $BACKUP_DIR/$BACKUP_NAME \
    -C $HOME \
    docker/jellyfin/config \
    docker/radarr/config \
    docker/sonarr/config \
    docker/prowlarr/config

# Restart containers
docker compose -f ~/docker/jellyfin/docker-compose.yml start
docker compose -f ~/docker/radarr/docker-compose.yml start
docker compose -f ~/docker/sonarr/docker-compose.yml start
docker compose -f ~/docker/prowlarr/docker-compose.yml start

# Retention - keep last 7
ls -t $BACKUP_DIR/mediaserver_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo "Backup complete: $BACKUP_NAME"
```

---

## Troubleshooting

### Jellyfin not detecting GPU

**Symptom:** Transcoding uses CPU instead of NVENC

**Fix:**
```bash
# Check NVIDIA runtime is available
docker info | grep -i runtime

# Verify GPU is visible in container
docker exec jellyfin nvidia-smi
```

### Media not appearing in library

**Symptom:** Files exist but Jellyfin doesn't show them

**Fixes:**
1. Check folder structure matches expected naming
2. Verify file permissions: `ls -la /mnt/hot/movies`
3. Trigger manual scan: Dashboard → Libraries → Scan All

### Playback buffering

**Symptom:** Video stutters or buffers frequently

**Fixes:**
1. Check if transcoding (Dashboard → Playback → Active)
2. Verify network speed between server and client
3. Try lowering quality in client settings
4. Check disk I/O: `iostat -x 1`

### Remote access not working

**Symptom:** Can't access services via Tailscale

**Fixes:**
1. Verify Tailscale is connected: `tailscale status`
2. Check subnet routes are approved in Tailscale admin
3. Verify Pi-hole is accessible from Tailscale IP
4. Test direct IP access first

### Automation not downloading

**Symptom:** Requests stuck in queue

**Fixes:**
1. Check Prowlarr → System → Status for indexer issues
2. Verify qBittorrent is accessible from Radarr/Sonarr
3. Check download client settings in Radarr/Sonarr
4. Review logs: `docker logs radarr`

---

## Useful Commands

### Docker

```bash
# List running containers
docker ps

# View logs
docker logs -f jellyfin

# Restart service
docker compose restart

# Update all images
docker compose pull && docker compose up -d

# Shell into container
docker exec -it jellyfin bash
```

### System Monitoring

```bash
# GPU usage
nvidia-smi

# CPU and memory
htop

# Disk usage
df -h

# Disk I/O
iostat -x 1

# Network connections
ss -tulnp
```

### Storage

```bash
# Check drive health
sudo smartctl -a /dev/sda

# Force HDD spin-down
sudo hdparm -y /dev/sdb

# Find large files
du -h /mnt/hot | sort -rh | head -20
```

### Tailscale

```bash
# Check status
tailscale status

# Get current IP
tailscale ip

# Reconnect
sudo tailscale up
```

---

## Future Considerations

- **Hardware upgrade path:** If transcoding demand grows, GPU upgrade provides most benefit
- **Storage expansion:** Add drives to cold tier as library grows
- **Redundancy:** Consider RAID or second backup location for irreplaceable content
- **4K adoption:** As more clients support HEVC, direct play increases
