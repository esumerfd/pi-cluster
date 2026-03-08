#!/usr/bin/env bash
set -euo pipefail

USER=${1:-$(whoami)}
HOST="control.local"

echo "--- Starting object detection on ${HOST} (Ctrl+C to stop)..."
ssh -t "${USER}@${HOST}" \
  "rpicam-hello -t 0 --post-process-file /usr/share/rpi-camera-assets/hailo_yolov8_inference.json"
