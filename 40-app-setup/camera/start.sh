#!/usr/bin/env bash
set -euo pipefail

USER=${1:-$(whoami)}
HOST="control.local"
PORT=8888

echo "--- Starting rpicam-vid on ${HOST}..."
ssh "${USER}@${HOST}" "
  nohup bash -c '
    while true; do
      rpicam-vid -t 0 -n --codec libav --libav-format mpegts \
        -o \"tcp://0.0.0.0:${PORT}?listen=1\" >> /tmp/camera.log 2>&1
      sleep 1
    done
  ' > /tmp/camera.log 2>&1 &
  echo \$! > /tmp/camera.pid
  echo 'rpicam-vid loop started (pid '\$(cat /tmp/camera.pid)')'
"

echo "--- Waiting for port ${PORT} to be ready..."
for i in $(seq 1 10); do
  if ssh "${USER}@${HOST}" "ss -tlnp | grep -q ':${PORT}'"; then
    echo "--- Port ${PORT} is ready."
    break
  fi
  sleep 1
done

echo "--- Launching VLC..."
vlc "tcp://${HOST}:${PORT}"

echo "--- VLC closed. Stopping rpicam-vid on ${HOST}..."
"$(dirname "$0")/stop.sh" "${USER}"
