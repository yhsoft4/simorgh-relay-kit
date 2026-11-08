#!/usr/bin/env bash
# Usage: sni-probe.sh HOST PORT SNI [SNI...]      run it from a machine INSIDE Iran
# Completes a TLS handshake with each SNI. If one SNI gets no reply while another works on the same port,
# the path filters by SNI (DPI), and the problem is the config's SNI, not the tunnel.
host="${1:?host}"; port="${2:?port}"; shift 2
for sni in "$@"; do
  if timeout 8 openssl s_client -connect "$host:$port" -servername "$sni" </dev/null 2>/dev/null | grep -q '^subject='; then
    echo "$sni  PASS"; else echo "$sni  NO REPLY"; fi
done
