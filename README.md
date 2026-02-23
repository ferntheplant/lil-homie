# lil homie

A mac mini home server sitting in my closet.

## Running it

### Environment Variables

Each stack gets its own `.env` file and examples are all in the single `example.env`.

## General

- everything is on docker compose
- docker running via orbstack
- all data for all services saved in `$DATA_PATH`
- each stack gets its own `stacks/<stack>/.env` plus shared `/.env.shared`
- stacks are independent compose projects, all bridged by the shared `caddy_network`

## Stacks + Manage Script

Stacks live under `stacks/<name>`, each with its own `docker-compose.yml` and optional `.env`.
Common env is in `.env.shared`. All stacks are started/stopped via the single script:

```bash
./stacks/manage.sh start
./stacks/manage.sh stop
./stacks/manage.sh restart
./stacks/manage.sh status
./stacks/manage.sh logs --follow
```

Target a single stack by name:

```bash
./stacks/manage.sh start yams
./stacks/manage.sh restart homie
```

Current stacks:

- `caddy`: meta stack (reverse proxy network + Portainer + Watchtower)
- `homie`: glance + monitors/utilities
- `yams`: media server (arr stack)
- `karakeep`: bookmarker + search
- `beeper`: bridge-manager services

### Meta Stack (caddy)

The `caddy` stack owns the shared reverse-proxy network and global tooling:

- Caddy reverse proxy
- Portainer (UI for docker management)
- Watchtower (auto-updates for labeled containers)

Watchtower runs in label-only mode. Any container with
`com.centurylinklabs.watchtower.enable=true` will auto-update. All services in this repo
are labeled.

Local images (e.g., `glance` built from `glance.Dockerfile` as `fjorn-glance:1.0.0`) are
not updated by Watchtower. Rebuild them manually when you want fresh upstream bits.

Portainer is reachable at:

- `https://lil-homie.tail8cc0d3.ts.net/portainer`

If admin setup fails behind the proxy, use `http://localhost:9000` once to create the admin user.
If Portainer shows `/timeout`, restart the `caddy` stack and complete the admin setup promptly.

## YAMS (ARR Stack)

The media server stack lives in `stacks/yams` and is a slimmed down YAMS setup:

- Jellyfin (media server)
- qBittorrent (torrent client)
- Sonarr / Radarr / Lidarr (media automation)
- Bazarr (subtitles)
- Prowlarr (indexers)

Notes:

- Media is stored at `/Users/fjorn/lil-homie/media`
- YAMS config lives under `/Users/fjorn/lil-homie/data/yams/config`
- The stack uses Caddy for subpath routing (e.g. `/sonarr`, `/radarr`, etc.)
- qBittorrent does not support a Base URL; Caddy strips the `/qbittorrent` prefix

### Running YAMS

```bash
./stacks/manage.sh start yams
./stacks/manage.sh stop yams
./stacks/manage.sh restart yams
```

### Base URLs (ARR Apps)

When accessed through Caddy subpaths, each app must be configured with a Base URL:

- Sonarr: `/sonarr`
- Radarr: `/radarr`
- Lidarr: `/lidarr`
- Bazarr: `/bazarr`
- Prowlarr: `/prowlarr`
- Jellyfin: `/jellyfin` (optional; can also be left blank and accessed on `:8096`)

### qBittorrent

qBittorrent does not expose a Base URL setting. Access it via:

- `https://lil-homie.tail8cc0d3.ts.net/qbittorrent`

Note: qBittorrent runs behind Gluetun. Caddy proxies `/qbittorrent` to `gluetun:8085` (not `qbittorrent`).

If the WebUI login loops when accessed via the reverse proxy, add these to
`$DATA_PATH/yams/config/qbittorrent/qBittorrent/qBittorrent.conf` under `[Preferences]`
and restart the `yams` stack:

```ini
WebUI\CSRFProtection=false
WebUI\HostHeaderValidation=false
WebUI\ReverseProxySupportEnabled=true
WebUI\TrustedReverseProxies=172.60.0.0/24,192.168.97.0/24
WebUI\RootFolder=
```

## Media Workflow (TV Show Idea → Jellyfin)

This is the end-to-end flow for adding a show and getting it into Jellyfin.

1. **Indexer**
   - Add or confirm your indexer in Prowlarr.
   - In Prowlarr: `Settings → Apps → + → Sonarr` and connect it using Sonarr’s API key.

2. **Download Client**
   - In Sonarr: `Settings → Download Clients → + → qBittorrent`
   - Use host `qbittorrent` and port `8085` (internal Docker network).
   - Ensure qBittorrent’s default save path is `/data/downloads`.

3. **Add the Show**
   - Sonarr → `Series → Add New`
   - Choose a path under `/data/tvshows/<Show Name>`
   - Pick your quality profile and language
   - Add the series

4. **Search**
   - In the series page, run “Search” to immediately grab monitored episodes.

5. **Jellyfin**
   - Jellyfin should have a TV library pointed at `/data/tvshows`
   - Run a library scan in Jellyfin if it doesn’t appear immediately

Notes:

- If Sonarr complains about missing `/downloads`, align qBittorrent to `/data/downloads`.
- qBittorrent downloads are visible to Sonarr via the shared `/data` mount.

## VPN + Port Forwarding (Remaining Steps)

If you want reliable torrent connectivity, you need a VPN provider that supports port forwarding.
Mullvad no longer supports port forwarding, so avoid it for this use-case.

To finish the VPN setup:

1. **Choose a provider with port forwarding**
   - Examples: Proton VPN (paid), AirVPN, OVPN

2. **Get WireGuard credentials**
   - Download the WireGuard config from the provider
   - Extract: private key, address, and server endpoint

3. **Update `stacks/yams/.env`**
   - Set `VPN_SERVICE_PROVIDER`, `VPN_TYPE=wireguard`,
     `WIREGUARD_PRIVATE_KEY`, `WIREGUARD_ADDRESSES`

4. **Route qBittorrent through Gluetun**
   - In `stacks/yams/docker-compose.yml`, enable:
     `network_mode: "service:gluetun"`

5. **Port forward**
   - Configure the forwarded port in your VPN provider dashboard
   - Set the same port as qBittorrent’s listening port

6. **Restart YAMS**
   - `./stacks/manage.sh restart yams`

Optional:

- Expose the forwarded port on the host if you are not routing through Gluetun
  and are using direct ISP connectivity.

### Proton VPN (Exact Steps)

Proton’s port forwarding works on **paid plans** and only on **P2P servers**. When generating a WireGuard config, you must enable **NAT-PMP (port forwarding)** and select a P2P server (double‑arrow icon). citeturn0search1turn0search2

1. Go to `account.protonvpn.com` → `Downloads` → `WireGuard configuration`. citeturn0search0
2. Create a config:
   - Choose a **P2P server**
   - Enable **NAT-PMP (port forwarding)**
3. Download the `.conf` file and extract:
   - **PrivateKey**
   - **Address**
   - **Endpoint** (server:port)
4. Update `stacks/yams/.env`:

```env
VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=...
WIREGUARD_ADDRESSES=...
```

5. In `stacks/yams/docker-compose.yml`, route qBittorrent through Gluetun:
   - `network_mode: "service:gluetun"`

6. Proton’s forwarded port can change when you reconnect. You must update qBittorrent’s listening port to match the current forwarded port each session. citeturn0search1

## Recovery

Quick debug loop for broken containers:

```bash
./stacks/manage.sh status
docker compose -f stacks/homie/docker-compose.yml --env-file /Users/fjorn/lil-homie/.env.shared ps
docker compose -f stacks/homie/docker-compose.yml --env-file /Users/fjorn/lil-homie/.env.shared logs --tail=200 <service>
```

### Backrest oplog corruption

If Backrest is crashing with an `oplog` migration error, it is safe to move the oplog sqlite file out of the way and restart:

```bash
mv $DATA_PATH/backrest/data/oplog.sqlite \
  $DATA_PATH/backrest/data/oplog.sqlite.bak-YYYYMMDD-HHMMSS
docker compose -f stacks/homie/docker-compose.yml --env-file /Users/fjorn/lil-homie/.env.shared up -d backrest
```

### Uptime Kuma sqlite corruption

If Uptime Kuma restarts with `SQLITE_CORRUPT`, try sqlite recovery first:

```bash
TIMESTAMP=YYYYMMDD-HHMMSS
mkdir -p $DATA_PATH/uptime-kuma/backup-$TIMESTAMP
cp -a $DATA_PATH/uptime-kuma/kuma.db \
  $DATA_PATH/uptime-kuma/kuma.db-wal \
  $DATA_PATH/uptime-kuma/kuma.db-shm \
  $DATA_PATH/uptime-kuma/backup-$TIMESTAMP/
sqlite3 $DATA_PATH/uptime-kuma/kuma.db ".recover" | \
  sqlite3 $DATA_PATH/uptime-kuma/kuma.db.recovered
mv $DATA_PATH/uptime-kuma/kuma.db \
  $DATA_PATH/uptime-kuma/kuma.db.bak-$TIMESTAMP
mv $DATA_PATH/uptime-kuma/kuma.db.recovered \
  $DATA_PATH/uptime-kuma/kuma.db
rm -f $DATA_PATH/uptime-kuma/kuma.db-wal \
  $DATA_PATH/uptime-kuma/kuma.db-shm
docker compose -f stacks/homie/docker-compose.yml --env-file /Users/fjorn/lil-homie/.env.shared up -d uptime-kuma
```

## MacOS Settings

TODO I know I did something for setting it up so I could unlock it after a restart via ssh. I forgot everything else I did. I am running macOS 26.

## Tailscale

All external access is via Tailscale. The host is `lil-homie.tail8cc0d3.ts.net`. Tailscale Serve publishes Caddy (and any dedicated listeners like Karakeep/Uptime Kuma) to the tailnet only.

Serve entrypoints:
- Caddy (main): `tailscale serve --bg 8080` → `https://lil-homie.tail8cc0d3.ts.net/`
- Karakeep (dedicated): `tailscale serve --bg --https 3003 3003` → `https://lil-homie.tail8cc0d3.ts.net:3003/`
- Uptime Kuma (dedicated): `tailscale serve --bg --https 3001 3001` → `https://lil-homie.tail8cc0d3.ts.net:3001/`

`./stacks/manage.sh start` will configure Tailscale Serve for all three ports. `./stacks/manage.sh stop` will remove the Serve config.

If `tailscale serve status` shows `No serve config`, run the three commands above once to initialize Serve for the tailnet (this triggers the one-time consent flow).
If `tailscale serve status` only shows one port, reset and reapply:

```bash
tailscale serve reset
./stacks/manage.sh start
```

If MagicDNS doesn’t resolve on a CLI-only client, add a resolver file:

```bash
sudo mkdir -p /etc/resolver
echo "nameserver 100.100.100.100" | sudo tee /etc/resolver/tail8cc0d3.ts.net
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## SSH

Using a classic SSH pub/priv key setup to SSH into the box over the tailnet. I had to disable async shell rendering (atuin, zsh-autosuggestions, fzf-tab) to get the SSH experience to not suck ass.

## Caddy

Caddy is a docker container reverse proxy. Containers I want to expose to the broader internet are on the docker compose `caddy_network` network. Apps are served under base paths like `/logs` so in the Caddyfile I either use `handle_path` to make it strip the base path when proxying or `handle` to get it to forward the path for apps that I could easily configure to have a base path (I forget which is which, ask Claude).

Since I want Karakeep accessible from apps and extensions it uses a separate Caddy listener and is published over Tailscale Serve.

## Syncthing

I just use Syncthing to keep a handful of folders in sync across my devices.

### Tailnet-only setup

Docker/Orbstack can't bind container ports directly to the Tailscale IP, so Syncthing's data port (`22000`) is restricted at the macOS firewall level and Syncthing is forced to use Tailscale addresses.

1) Apply the pf rule (macOS firewall)

```bash
sudo /Users/fjorn/lil-homie/scripts/setup-pf-tailscale-syncthing.sh utun4
```

Find the correct interface with:

```bash
ifconfig | rg -n "utun|100\\." -C 2
```

2) Configure Syncthing listen addresses (each device listens on its own tailnet IP)

Server (`lil-homie`):
- `tcp://<server_tailnet_ip>:22000`
- `quic://<server_tailnet_ip>:22000`

Laptop:
- `tcp://<laptop_tailnet_ip>:22000`
- `quic://<laptop_tailnet_ip>:22000`

3) Configure device addresses (each device points at the other's tailnet IP)

Laptop → server:
- `tcp://<server_tailnet_ip>:22000`

Server → laptop:
- `tcp://<laptop_tailnet_ip>:22000`

Optional (strict tailnet-only):
- Disable Global Discovery and Relays in `Settings → Connections`

Restart Syncthing after changes:

```bash
./stacks/manage.sh restart homie
```

## Backrest

I use [Backrest](https://github.com/garethgeorge/backrest) to get a ncie UI for setting up backups of my important folders. The backups are encrypted and stored in a Cloudflare R2 bucket.

## Karakeep

Served on a dedicated listener via Tailscale Serve for mobile/extension compatibility:

- `https://lil-homie.tail8cc0d3.ts.net:3003/`

### Ollama

## Uptime Kuma

Uptime Kuma doesn’t support sub-routes. It runs on a dedicated listener and is published via Tailscale Serve:

- `https://lil-homie.tail8cc0d3.ts.net:3001/`

If it restarts with a migration lock error, clear the lock in `kuma.db`:

```bash
./stacks/manage.sh stop homie
sqlite3 $DATA_PATH/uptime-kuma/kuma.db "DELETE FROM knex_migrations_lock;"
sqlite3 $DATA_PATH/uptime-kuma/kuma.db "INSERT INTO knex_migrations_lock (is_locked) VALUES (0);"
./stacks/manage.sh start homie
```

## Beeper

Beeper provides a unified messaging experience. The beeper apps aren't that good but I don't want to configure Matrix from scratch so they'll have to suffice. Their docs are pretty good.

### iMessage

To get iMessage to work I needed to grant the `bbctl` program full disk access so it could mess with the OS system iMessage stuff. This is the only service that isn't running in a container because it needs access to the host. I did set it up as a `launchctl` agent using the [agent install script](https://github.com/ferntheplant/dotfiles/blob/ae4a81ad2e85fa53e1327124a89bb7922abfd4f9/scripts/install-agent.sh) from my dotfiles.

### iMessage Monitor

To monitor the status of the iMessage bridge in my server dashboard I set up a little monitor script in `imessage-monitor.py`. The script needs a wrapper in `imessage-monitor.sh` to setup all the mise hooks for using my desired version of python. This monitor itself is also registered as a `launchctl` agent using the same install script. The monitor script serves a simple HTTP endpoint for checking the status of specific `launchctl` agents - specifically the iMessage monitor.

## Glance

Glance is the server dashboard. It shows me a quick status of everything running on the box along with some extra goodies. Complex widgets have their own config file in `glance-config/widget-config`. To get the Glance server to use my desired timezone I had to extend the default docker image with `glance.Dockerfile`. Build it with the tag `fjorn-glance:1.0.0` before running `docker compose up -d`.

Glance lives in the `homie` stack. The page config lives in `glance-config/` and is mounted into the container. Custom behavior in this repo:

- `glance.Dockerfile` pins timezone handling in the image.
- `glance-config/widget-config` contains complex widgets, including the `launchctl` agent monitor.
- Some widgets require app-side base paths (see notes below), and some services need custom `APP_URL` settings.

### [Karakeep](https://github.com/glanceapp/community-widgets/blob/main/widgets/karakeep-dashboard/README.md)

No changes from the default settings.

### [Uptime Kuma](https://github.com/glanceapp/community-widgets/blob/main/widgets/uptime-kuma/README.md)

No changes

### [Beszel](https://github.com/glanceapp/community-widgets/blob/main/widgets/beszel-metrics/README.md)

Beszel provides monitoring over time of all the containers' system usage. Beszel is proxied by Caddy behind `/beszel` so I had to do some stuff with the `APP_URL` env variable and `handle_path`. Ask Claude lol. The widget is not modified from the community base.

TODO: find a way to notify when the API token is expired

### [Syncthing](https://github.com/glanceapp/community-widgets/blob/main/widgets/syncthing/README.md)

The Syncthing glance widget is mostly unchanged - just swapped hard coded values for env variables.

### [Backrest](https://github.com/not-first/restic-glance-extension)

For a remote repo you don't need to mount any volumes - just set the env variables. If there are no backups then you'll get weird error messages in the widget so just ensure at least one snapshot exists.

### `launchctl` agents

Claude wrote the `launchctl-agents.yml` widget. It uses the HTTP server for the imessage monitor as discussed before.

### [gcal](https://github.com/AWildLeon/Glance-iCal-Events)

Just set the widget to use `parseTimeLocal` for local timestamps on the calendar events.

### [Speedtest](https://github.com/glanceapp/community-widgets/blob/main/widgets/speedtest-tracker/README.md)

This was mostly a meme. Just followed basic instructions for the service and widget.

### [Spotify](https://github.com/glanceapp/community-widgets/blob/main/widgets/spotify-player/README.md)

Sussy.

### [AQI](https://github.com/glanceapp/community-widgets/blob/main/widgets/air-quality/README.md)

Again just for the meme. Just followed default instructions for the widget.

### [Weather](https://github.com/glanceapp/community-widgets/blob/main/widgets/weather-seven-day/README.md)

Just followed basic instructions for the widget.

## TODO

- keep portainer + watchtower in the caddy "meta" stack
