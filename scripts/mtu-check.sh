#!/usr/bin/env bash
# Usage: mtu-check.sh PEER_TUNNEL_IP      e.g. mtu-check.sh 10.10.0.1   (run on either end)
# Pings the other end with the Don't-Fragment bit at growing sizes. A stall at large sizes while small pings
# work is the classic "handshake OK, real traffic stalls" MTU problem.
peer="${1:?usage: mtu-check.sh PEER_TUNNEL_IP}"
ip -br link show bp0 2>/dev/null
for s in 1372 1300 1200 1000 600; do
  if ping -M do -c 2 -W 2 -s "$s" "$peer" >/dev/null 2>&1; then echo "payload $s: ok"; else echo "payload $s: FAIL"; fi
done
iptables -t mangle -S 2>/dev/null | grep -i mss || echo "(no TCP MSS clamp rule visible here)"
