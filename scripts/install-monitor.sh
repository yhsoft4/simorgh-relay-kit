#!/usr/bin/env bash
# Installs monitor.sh as a systemd timer (every 5 minutes). Run as root on the
# server abroad.
# Usage: install-monitor.sh IRAN_IP PORT [PORT...]
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ $# -ge 2 ] || { echo "usage: $0 IRAN_IP PORT [PORT...]" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"

install -m 755 "$here/monitor.sh" /usr/local/bin/bp-monitor

cat > /etc/systemd/system/bp-monitor.service <<EOF
[Unit]
Description=BackPack reachability monitor

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bp-monitor $*
EOF

cat > /etc/systemd/system/bp-monitor.timer <<'EOF'
[Unit]
Description=Run BackPack reachability monitor every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now bp-monitor.timer
echo "Installed. Log: /var/log/bp-monitor.log   (tail -f it; 'CHANGE' lines mark state flips)"
echo "Remove with: systemctl disable --now bp-monitor.timer && rm /etc/systemd/system/bp-monitor.* /usr/local/bin/bp-monitor"
