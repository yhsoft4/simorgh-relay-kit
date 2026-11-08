#!/usr/bin/env bash
# Reachability monitor for a BackPack tunnel. Run it from the server ABROAD
# (that is the vantage point the filter blocks). Appends one line per run to a
# log and an extra "CHANGE" line whenever the state flips, so you get exact
# timestamps of when an IP became unreachable (evidence for a support ticket).
#
# Usage: monitor.sh IRAN_IP PORT [PORT...]
# Env:   TUNNEL_IP   tunnel address of the other end to ping (default 10.10.0.1)
#        SERVICE     tunnel systemd unit to check (default: first backpack-l3-*)
#        LOG         log file (default /var/log/bp-monitor.log)
#        STATE       state file (default /var/lib/bp-monitor.state)
# Changes nothing except its own log and state file.
set -u
[ $# -ge 2 ] || { echo "usage: $0 IRAN_IP PORT [PORT...]" >&2; exit 2; }
ip="$1"; shift
TUNNEL_IP="${TUNNEL_IP:-10.10.0.1}"
LOG="${LOG:-/var/log/bp-monitor.log}"
STATE="${STATE:-/var/lib/bp-monitor.state}"
SERVICE="${SERVICE:-$(systemctl list-units --no-legend 'backpack-l3-*' 2>/dev/null | awk '{print $1}' | head -1)}"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

if ping -c3 -W2 "$ip" >/dev/null 2>&1; then pub=OK; else pub=FAIL; fi

open=0; total=0
for p in "$@"; do
  total=$((total + 1))
  timeout 5 bash -c "exec 3<>/dev/tcp/${ip}/${p}" 2>/dev/null && open=$((open + 1))
done

if ping -c3 -W2 "$TUNNEL_IP" >/dev/null 2>&1; then tun=OK; else tun=FAIL; fi

svc=unknown; flaps=0
if [ -n "$SERVICE" ]; then
  svc=$(systemctl is-active "$SERVICE" 2>/dev/null || true)
  flaps=$(journalctl -u "$SERVICE" --since "-6min" --no-pager 2>/dev/null | grep -ciE 'nothing heard|restarting client')
fi

line="$(now) ip=${ip} public_ping=${pub} ports=${open}/${total} tunnel_ping=${tun} service=${svc} flaps_6min=${flaps}"
echo "$line" >> "$LOG"

key="${pub}|${open}/${total}|${tun}|${svc}"
prev="$(cat "$STATE" 2>/dev/null || true)"
if [ "$key" != "$prev" ]; then
  echo "$(now) CHANGE ${prev:-none} -> ${key}" >> "$LOG"
  printf '%s' "$key" > "$STATE"
fi
exit 0
