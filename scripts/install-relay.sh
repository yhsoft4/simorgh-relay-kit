#!/usr/bin/env bash
# One-purpose installer for THIS relay only: BackPack Direct PCK layer-3 tunnel, Iran side DIALS OUT to kharej.
# It installs the official, unmodified BackPack release, then writes one config + one systemd unit for it.
#
#   kharej (abroad):  sudo bash install-relay.sh kharej [--port 9000]
#   iran:             sudo TUNNEL_TOKEN=... bash install-relay.sh iran KHAREJ_IP --ports "80,8080,8443,2053" [--port 9000]
#   status:           bash install-relay.sh status
#   uninstall:        sudo bash install-relay.sh uninstall       (removes this relay's config/unit, not BackPack)
# Add --dry-run to print the config instead of installing. Token: generated on kharej, passed to Iran via
# TUNNEL_TOKEN (or typed at a hidden prompt). A ports entry may be "443=OTHER_IP:443".
# Based on BackPack by Amin Mohammadi (AminMGMT), https://github.com/AminMGMT/BackPack
set -euo pipefail

ROOT="${RELAY_ROOT:-}"                    # test hook: prefix for /etc paths
CONF="$ROOT/etc/backpack/relay.toml"; UNIT="$ROOT/etc/systemd/system/backpack-relay.service"
OFFICIAL="https://raw.githubusercontent.com/AminMGMT/BackPack/main/install.sh"
role="${1:-}"; shift || true
port=9000; ports=""; dry=0; kharej_ip=""
[ "$role" = iran ] && { kharej_ip="${1:-}"; shift || true; }
while [ $# -gt 0 ]; do
  case "$1" in --port) port="$2"; shift 2;; --ports) ports="$2"; shift 2;; --dry-run) dry=1; shift;; *) echo "unknown option: $1" >&2; exit 2;; esac
done

status() {
  systemctl is-active backpack-relay 2>/dev/null || true
  ip -br addr show bp0 2>/dev/null || { echo "bp0 not up"; return 0; }
  if ip -4 -o addr show bp0 | grep -q '10\.10\.0\.1/'; then peer=10.10.0.2; else peer=10.10.0.1; fi
  ping -c 3 -W 2 "$peer" | tail -2
}
case "$role" in
  status) status; exit 0;;
  uninstall)
    [ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
    systemctl disable --now backpack-relay 2>/dev/null || true; rm -f "$CONF" "$UNIT"; systemctl daemon-reload; echo "removed"; exit 0;;
  kharej|iran) ;;
  *) sed -n 2,11p "$0"; exit 2;;
esac

if [ "$role" = iran ]; then
  [ -n "$kharej_ip" ] || { echo "iran needs KHAREJ_IP" >&2; exit 2; }
  [ -n "$ports" ] || { echo "iran needs --ports \"80,443,...\"" >&2; exit 2; }
  token="${TUNNEL_TOKEN:-}"
  if [ -z "$token" ] && [ "$dry" = 0 ]; then read -rsp "Tunnel token from the kharej server: " token; echo; fi
  [ -n "$token" ] || token="DRY_RUN_TOKEN"
  plist=$(printf '%s' "$ports" | awk -F, '{for(i=1;i<=NF;i++){gsub(/ /,"",$i);printf "%s\"%s\"",(i>1?", ":""),$i}}')
  body=$(cat <<EOF
[l3]
mode         = "dial"
addr         = "$kharej_ip:$port"
token        = "$token"
carrier      = "pck"
encap        = "gre"
iface        = "bp0"
local_ip     = "10.10.0.1/30"
peer_ip      = "10.10.0.2"
mtu          = 1400
preset       = "balance"
txqueuelen   = 1024
qdisc        = "fq_codel"
sockbuf      = 4194304
ports        = [$plist]
accept_udp   = true
EOF
)
else
  token="${TUNNEL_TOKEN:-$(openssl rand -hex 32)}"
  body=$(cat <<EOF
[l3]
mode         = "listen"
addr         = "0.0.0.0:$port"
token        = "$token"
carrier      = "pck"
encap        = "gre"
iface        = "bp0"
local_ip     = "10.10.0.2"
peer_ip      = "10.10.0.1"
mtu          = 1400
preset       = "balance"
txqueuelen   = 1024
qdisc        = "fq_codel"
sockbuf      = 4194304
EOF
)
fi

if [ "$dry" = 1 ]; then printf '%s\n' "$body" | sed -E 's/^(token +=).*/\1 "<hidden>"/'; exit 0; fi
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
if systemctl list-units --no-legend 'backpack-l3-*' 2>/dev/null | grep -q running; then
  echo "Another BackPack l3 tunnel is running and would clash on bp0. Stop it first." >&2; exit 1; fi

if [ ! -x /usr/local/bin/backpack ]; then
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  curl -fsSL --connect-timeout 15 "$OFFICIAL" -o "$tmp"; bash "$tmp" </dev/null
fi
/usr/local/bin/backpack -v

mkdir -p "$(dirname "$CONF")"; [ -f "$CONF" ] && cp "$CONF" "$CONF.bak-$(date +%s)"
umask 077; printf '%s\n' "$body" > "$CONF"; umask 022
printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/99-relay.conf; sysctl -q -p /etc/sysctl.d/99-relay.conf
cat > "$UNIT" <<EOF
[Unit]
Description=Relay tunnel (BackPack Direct PCK l3, $role)
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/backpack -c $CONF
Restart=always
RestartSec=3
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable --now backpack-relay

if [ "$role" = kharej ]; then
  command -v ufw >/dev/null && ufw status | grep -q active && { ufw allow "$port"/tcp; ufw allow "$port"/udp; }
  echo
  echo "Kharej side is up, listening on :$port (open it in any cloud firewall too)."
  echo "On the Iran server run (the token is secret, do not post it):"
  echo "  sudo TUNNEL_TOKEN='$token' bash install-relay.sh iran THIS_SERVER_IP --ports \"80,8080,8443\" --port $port"
else
  echo "Waiting for the tunnel..."; for _ in $(seq 1 20); do ping -c 1 -W 1 10.10.0.2 >/dev/null 2>&1 && { echo "Tunnel is up: 10.10.0.2 answers."; exit 0; }; sleep 1; done
  echo "No answer from 10.10.0.2 yet. Check: journalctl -u backpack-relay -n 30" >&2; exit 1
fi
