# lil homie

A mac mini home server sitting in my closet.

## General

- everything is on docker compose
- docker running via orbstack
- all data for all services saved in `$DATA_PATH`

## MacOS Settings

TODO

I know I did somethign for setting it up so I could unlock it after a restart via ssh. I forgot everything else I did. I am running macOS 26.

## Cloudflare

I'm using Cloudflare Tunnels to connect the server to the internet at large. I suffered through the cloudflare dashboard because I did not feel like learning their config schema.

TODO: setup IaC for cloudflare config

There is a single tunnel routing to this machine. The cloudflare tunnel is running via `cloudflared` as a `launchctl` daemon. On it are 2 published applications, one for Caddy and one for SSH, published on subdomains. These applications have corresponding "Applications" in the Zero Trust Access section pointing to the subdomains from the Tunnel config. The applications have access policies set so only my cloudflare account can access the tunnels.

## SSH

Using a classic SSH pub/priv key setup to SSH into the box. The cloudflare tunnel just points to `localhost:22`. I had to disable async shell rendering (atuin, zsh-autosuggestions, fzf-tab) to get the SSH experience to not suck ass.

## Caddy

Caddy is a docker container reverse proxy. Containers I want to expose to the broader internet are on the docker compose `proxy_network` network. Apps are served under base paths like `/logs` so in the Caddyfile I either use `handle_path` to make it strip the base path when proxying or `handle` to get it to forward tha path for apps that I could easily configure to have a base path (I forget which is which, ask Claude).

Since I want Karakeep accessible from apps and extensions it uses a different Caddy network that routes to a different Cloudflare tunnel with separate access control settings.

## Syncthing

I just use Syncthing to keep a handful of folders in sync across my devices.

## Backrest

I use [Backrest](https://github.com/garethgeorge/backrest) to get a ncie UI for setting up backups of my important folders. The backups are encrypted and stored in a Cloudflare R2 bucket.

## Karakeep

TODO

### Ollama

## Beeper

Beeper provides a unified messaging experience. The beeper apps aren't that good but I don't want to configure Matrix from scratch so they'll have to suffice. Their docs are pretty good.

### iMessage

To get iMessage to work I needed to grant the `bbctl` program full disk access so it could mess with the OS system iMessage stuff. This is the only service that isn't running in a container because it needs access to the host. I did set it up as a `launchctl` agent using the [agent install script](https://github.com/ferntheplant/dotfiles/blob/ae4a81ad2e85fa53e1327124a89bb7922abfd4f9/scripts/install-agent.sh) from my dotfiles.

### iMessage Monitor

To monitor the status of the iMessage bridge in my server dashboard I set up a little monitor script in `imessage-monitor.py`. The script needs a wrapper in `imessage-monitor.sh` to setup all the mise hooks for using my desired version of python. This monitor itself is also registered as a `launchctl` agent using the same install script. The monitor script serves a simple HTTP endpoint for checking the status of specific `launchctl` agents - specifically the iMessage monitor.

## Glance

Glance is the server dashboard. It shows me a quick status of everything running on the box along with some extra goodies. Complex widgets have their own config file in `glance-config/widget-config`. To get the Glance server to use my desired timezone I had to extend the default docker image with `glance.Dockerfile`. Build it with the tag `fjorn-glance:1.0.0` before running `docker compose up -d`.

### [Karakeep](https://github.com/glanceapp/community-widgets/blob/main/widgets/karakeep-dashboard/README.md)

No changes from the default settings.

### [Beszel](https://github.com/glanceapp/community-widgets/blob/main/widgets/beszel-metrics/README.md)

Beszel provides monitoring over time of all the containers' system usage. Beszel is proxied by Caddy behind `/beszel` so I had to do some stuff with the `APP_URL` env variable and `handle_path`. Ask Claude lol. The widget is not modified from the community base.

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

