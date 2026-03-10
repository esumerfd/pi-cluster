#!/usr/bin/env bash
set -euo pipefail

USER=${1:-$(whoami)}
NAME=${2:-}

if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <user> <pi-name>"
  echo "  pi-name: control, worker1, worker2"
  exit 1
fi

HOST="${NAME}.local"

echo "--- Identifying ${NAME} (${HOST}) by flashing ACT LED..."

ssh "${USER}@${HOST}" 'bash -s' << 'REMOTE'
LED=/sys/class/leds/ACT
if [[ ! -d "$LED" ]]; then
  # Fallback path used on some Pi OS versions
  LED=$(ls -d /sys/class/leds/led* 2>/dev/null | head -1)
fi

if [[ -z "$LED" || ! -d "$LED" ]]; then
  echo "ERROR: No controllable LED found" >&2
  exit 1
fi

original=$(cat "$LED/trigger" | grep -oP '\[\K[^\]]+')
echo "none" | sudo tee "$LED/trigger" > /dev/null

for i in $(seq 1 10); do
  echo 1 | sudo tee "$LED/brightness" > /dev/null
  sleep 0.1
  echo 0 | sudo tee "$LED/brightness" > /dev/null
  sleep 0.1
done

echo "$original" | sudo tee "$LED/trigger" > /dev/null
echo "Done. LED trigger restored to: $original"
REMOTE

echo "--- Done identifying ${NAME}."
