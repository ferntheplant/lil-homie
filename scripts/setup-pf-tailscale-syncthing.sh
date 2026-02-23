#!/bin/bash
set -euo pipefail

IFACE="${1:-utun4}"
ANCHOR_FILE="/private/etc/pf.anchors/tailscale-syncthing"
PF_CONF="/private/etc/pf.conf"

cat > "${ANCHOR_FILE}" <<RULES
pass in quick on ${IFACE} proto tcp from any to any port 22000
pass in quick on ${IFACE} proto udp from any to any port 22000
block drop in quick proto tcp from any to any port 22000
block drop in quick proto udp from any to any port 22000
RULES

if ! grep -q "tailscale-syncthing" "${PF_CONF}"; then
  printf '\nanchor "tailscale-syncthing"\nload anchor "tailscale-syncthing" from "/private/etc/pf.anchors/tailscale-syncthing"\n' >> "${PF_CONF}"
fi

pfctl -f "${PF_CONF}"
pfctl -e || true

echo "pf rules loaded. Syncthing is now tailnet-only on ${IFACE}."
