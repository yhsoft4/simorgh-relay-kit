#!/usr/bin/env bash
# Check that TCP ports on a host accept connections. Changes nothing.
# Usage: bash check-ports.sh HOST PORT [PORT...]
set -u
if [ $# -lt 2 ]; then
  echo "usage: $0 HOST PORT [PORT...]" >&2
  exit 2
fi
host="$1"; shift
fail=0
for p in "$@"; do
  if timeout 6 bash -c "exec 3<>/dev/tcp/${host}/${p}" 2>/dev/null; then
    echo "${p} open"
  else
    echo "${p} CLOSED"; fail=1
  fi
done
exit $fail
