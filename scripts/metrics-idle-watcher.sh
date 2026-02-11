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

if ! command -v loginctl >/dev/null 2>&1; then
  echo "loginctl is required for idle detection." >&2
  exit 1
fi

get_idle_ms() {
  local session_id idle_hint idle_since_us now_us idle_us
  session_id="${XDG_SESSION_ID:-}"
  if [[ -z "$session_id" ]]; then
    session_id="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v user="$USER" '$3==user {print $1; exit}')"
  fi

  if [[ -z "$session_id" ]]; then
    return 1
  fi

  idle_hint="$(loginctl show-session "$session_id" -p IdleHint --value 2>/dev/null || true)"
  if [[ "$idle_hint" != "yes" ]]; then
    echo "0"
    return 0
  fi

  idle_since_us="$(loginctl show-session "$session_id" -p IdleSinceHintMonotonicUSec --value 2>/dev/null || true)"
  if [[ "$idle_since_us" =~ ^[0-9]+$ ]]; then
    now_us="$(awk '{printf "%.0f\n", $1 * 1000000}' /proc/uptime 2>/dev/null || true)"
    if [[ "$now_us" =~ ^[0-9]+$ ]] && (( now_us >= idle_since_us )); then
      idle_us=$((now_us - idle_since_us))
      echo $((idle_us / 1000))
      return 0
    fi
  fi

  return 1
}

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
  if ! idle_ms="$(get_idle_ms)"; then
    echo "Unable to read idle time from loginctl; retrying..." >&2
    stop_kiosk
    sleep "$POLL_SECONDS"
    continue
  fi

  if (( idle_ms >= IDLE_TIMEOUT_MS )) && ! is_browser_media_playing; then
    start_kiosk
  else
    stop_kiosk
  fi

  sleep "$POLL_SECONDS"
done
