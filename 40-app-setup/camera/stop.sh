#!/usr/bin/env bash
set -euo pipefail

USER=${1:-$(whoami)}
HOST="control.local"

echo "--- Stopping rpicam-vid on ${HOST}..."
ssh "${USER}@${HOST}" "
  if [ -f /tmp/camera.pid ]; then
    kill \$(cat /tmp/camera.pid) 2>/dev/null && echo 'rpicam-vid stopped.'
    rm /tmp/camera.pid
  else
    echo 'No camera.pid found, killing by name...'
    pkill -f rpicam-vid || true
  fi
"
