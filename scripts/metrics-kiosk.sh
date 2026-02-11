#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${METRICS_CONFIG_FILE:-$SCRIPT_DIR/metrics-kiosk.conf}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config not found: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

if [[ -z "${URLS[*]:-}" ]]; then
  echo "No URLs configured." >&2
  exit 1
fi

if ! command -v "$CHROMIUM_BIN" >/dev/null 2>&1; then
  echo "Chromium binary not found: $CHROMIUM_BIN" >&2
  exit 1
fi

PROFILE_DIR="${XDG_RUNTIME_DIR:-/tmp}/metrics-kiosk-profile"
mkdir -p "$PROFILE_DIR"

cleanup() {
  pkill -f "--class=metrics-kiosk" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

index=0
count="${#URLS[@]}"

while true; do
  url="${URLS[$index]}"

  "$CHROMIUM_BIN" \
    --class=metrics-kiosk \
    --user-data-dir="$PROFILE_DIR" \
    --kiosk \
    --no-first-run \
    --disable-features=Translate \
    --autoplay-policy=no-user-gesture-required \
    "$url" >/dev/null 2>&1 &

  pid=$!

  elapsed=0
  while kill -0 "$pid" >/dev/null 2>&1 && (( elapsed < ROTATE_SECONDS )); do
    sleep 1
    ((elapsed+=1))
  done

  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" 2>/dev/null || true

  index=$(( (index + 1) % count ))
  sleep 1
done
