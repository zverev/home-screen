#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${METRICS_CONFIG_FILE:-$SCRIPT_DIR/metrics-kiosk.conf}"
KIOSK_SCRIPT="${METRICS_KIOSK_SCRIPT:-$SCRIPT_DIR/metrics-kiosk.sh}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config not found: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

if ! command -v xprintidle >/dev/null 2>&1; then
  echo "xprintidle is required (sudo apt install xprintidle)" >&2
  exit 1
fi

is_browser_media_playing() {
  if ! command -v playerctl >/dev/null 2>&1; then
    return 1
  fi

  local player
  while IFS= read -r player; do
    if playerctl -p "$player" status 2>/dev/null | grep -qx 'Playing'; then
      return 0
    fi
  done < <(playerctl --list-all 2>/dev/null | grep -E 'chromium|chrome' || true)

  return 1
}

kiosk_pid=""

start_kiosk() {
  if [[ -n "$kiosk_pid" ]] && kill -0 "$kiosk_pid" >/dev/null 2>&1; then
    return
  fi

  "$KIOSK_SCRIPT" &
  kiosk_pid=$!
}

stop_kiosk() {
  if [[ -n "$kiosk_pid" ]] && kill -0 "$kiosk_pid" >/dev/null 2>&1; then
    kill "$kiosk_pid" >/dev/null 2>&1 || true
    wait "$kiosk_pid" 2>/dev/null || true
  fi

  kiosk_pid=""
  pkill -f "--class=metrics-kiosk" >/dev/null 2>&1 || true
}

cleanup() {
  stop_kiosk
}

trap cleanup EXIT INT TERM

while true; do
  idle_ms="$(xprintidle)"

  if (( idle_ms >= IDLE_TIMEOUT_MS )) && ! is_browser_media_playing; then
    start_kiosk
  else
    stop_kiosk
  fi

  sleep "$POLL_SECONDS"
done
