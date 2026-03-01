#!/usr/bin/env bash
# Poll network connectivity of all Pi nodes in the cluster.
# Uses the inventory.yml in the project root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY="$PROJECT_ROOT/inventory.yml"
INTERVAL="${POLL_INTERVAL:-5}"

HOSTS=(
  "control:control.local"
  "worker1:worker1.local"
  "worker2:worker2.local"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

ping_host() {
  local ip="$1"
  ping -c 1 -W 1 "$ip" &>/dev/null
}

ssh_check() {
  local ip="$1"
  nc -z -w 2 "$ip" 22 &>/dev/null
}

check_all() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "${BOLD}[$timestamp]${RESET}"

  for entry in "${HOSTS[@]}"; do
    local name="${entry%%:*}"
    local ip="${entry##*:}"

    printf "  %-10s (%s)  " "$name" "$ip"

    if ping_host "$ip"; then
      printf "${GREEN}PING OK${RESET}  "
    else
      printf "${RED}PING FAIL${RESET}  "
    fi

    if ssh_check "$ip"; then
      printf "${GREEN}SSH OK${RESET}\n"
    else
      printf "${YELLOW}SSH FAIL${RESET}\n"
    fi
  done

  echo ""
}

if [[ "${1:-}" == "--once" ]]; then
  check_all
else
  echo "Polling Pi cluster every ${INTERVAL}s (Ctrl+C to stop)"
  echo ""
  while true; do
    check_all
    sleep "$INTERVAL"
  done
fi
