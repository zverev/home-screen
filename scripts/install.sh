#!/usr/bin/env bash
set -euo pipefail

# Resolve paths relative to this script so it can be run from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Fail fast if a required command is unavailable.
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

# Wrapper keeps user-level systemd calls in one place.
run_user_systemctl() {
  systemctl --user "$@"
}

# Install runtime dependencies used by the kiosk scripts.
install_dependencies() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found. This installer currently supports Raspberry Pi OS / Debian-based systems." >&2
    exit 1
  fi

  echo "Installing OS dependencies..."
  sudo apt-get update
  sudo apt-get install -y chromium xprintidle playerctl
}

# Install scripts/service files and refresh config from repository defaults.
install_files() {
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/.config/systemd/user"

  install -m 755 "$ROOT_DIR/scripts/metrics-kiosk.sh" "$HOME/.local/bin/metrics-kiosk.sh"
  install -m 755 "$ROOT_DIR/scripts/metrics-idle-watcher.sh" "$HOME/.local/bin/metrics-idle-watcher.sh"

  install -m 644 "$ROOT_DIR/scripts/metrics-kiosk.conf" "$HOME/.local/bin/metrics-kiosk.conf"
  echo "Updated config: $HOME/.local/bin/metrics-kiosk.conf"

  install -m 644 "$ROOT_DIR/systemd/user/metrics-idle-watcher.service" "$HOME/.config/systemd/user/metrics-idle-watcher.service"
}

# Reload unit definitions and ensure the watcher is enabled/running.
enable_service() {
  echo "Enabling and starting user service..."
  run_user_systemctl daemon-reload
  run_user_systemctl enable --now metrics-idle-watcher.service
}

# Main entrypoint: validate tools, install everything, then print next steps.
main() {
  require_cmd sudo
  require_cmd systemctl
  require_cmd install

  install_dependencies
  install_files
  enable_service

  cat <<'EOF'

Install complete.

Next:
  1) Edit URLs/timers:
     nano ~/.local/bin/metrics-kiosk.conf
  2) Check service:
     systemctl --user status metrics-idle-watcher.service
  3) Follow logs:
     journalctl --user -u metrics-idle-watcher.service -f
EOF
}

main "$@"
