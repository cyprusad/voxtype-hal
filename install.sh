#!/bin/bash
# voxtype-hal installer — HAL 9000 eye OSD for Voxtype dictation.
#
# One command, clean replace:
#   ./install.sh
#
# What it does:
#   1. Copies this style package to ~/.config/voxtype/osd/voxtype-hal/
#   2. Backs up ~/.config/voxtype/config.toml (timestamped, kept forever)
#      + records the exact original OSD values for surgical revert
#   3. Switches [osd] to the quickshell HAL eye, silences the
#      "recording stopped" desktop notification (the eye shows state now)
#   4. Restarts voxtype and verifies the daemon is idle-ready
#
# Revert any time with: ./uninstall.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/voxtype/osd/voxtype-hal"
CONFIG="${HOME}/.config/voxtype/config.toml"
BACKUP_ENV="${TARGET_DIR}/.hal-backup.env"
RESTART=true

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET_DIR="$2"; shift 2 ;;
    --no-restart) RESTART=false; shift ;;
    -h|--help)
      echo "Usage: ./install.sh [--target DIR] [--no-restart]"
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
need voxtype
need systemctl
if ! command -v qs >/dev/null 2>&1 && [ ! -x /usr/lib/voxtype/voxtype-osd-quickshell ]; then
  echo "Quickshell OSD backend not found (need 'qs' or voxtype-osd-quickshell)." >&2
  exit 1
fi

get_or_unset() {  # $1 = key -> prints value or __UNSET__
  local val
  if val="$(voxtype config get "$1" 2>/dev/null)"; then
    printf '%s' "$val"
  else
    printf '__UNSET__'
  fi
}

echo "== voxtype-hal: installing HAL eye OSD =="

# 1. Install the style package
mkdir -p "$TARGET_DIR"
cp "$REPO_DIR/voxtype-osd.toml" "$REPO_DIR/Hal.qml" "$TARGET_DIR/"
echo "Package installed to $TARGET_DIR"

# Clear the opt-out sentinel so the bundled Omarchy service (if installed
# as io.github.cyprusad.voxtype-hal) keeps the eye applied on shell start.
rm -f "$(dirname "$TARGET_DIR")/.hal-disabled"

# 2a. Full config backup (first install only is enough; always keep prior ones)
if ! ls "${CONFIG}.pre-hal-"* >/dev/null 2>&1; then
  cp "$CONFIG" "${CONFIG}.pre-hal-$(date +%Y%m%d-%H%M%S)"
  echo "Config backed up to ${CONFIG}.pre-hal-*"
else
  echo "Existing pre-hal backup found, keeping it"
fi

# 2b. Record exact original values for surgical revert
{
  echo "# Original values recorded by voxtype-hal install on $(date -u +%FT%TZ)"
  echo "osd.frontend=$(get_or_unset osd.frontend)"
  echo "osd.style=$(get_or_unset osd.style)"
  echo "osd.palette=$(get_or_unset osd.palette)"
  echo "osd.layout=$(get_or_unset osd.layout)"
  echo "output.notification.on_recording_stop=$(get_or_unset output.notification.on_recording_stop)"
} > "$BACKUP_ENV"
echo "Original OSD values recorded in $BACKUP_ENV"

# 3. Apply the HAL configuration
voxtype config set osd.frontend quickshell
voxtype config set osd.style "$TARGET_DIR"
voxtype config set osd.palette package
voxtype config set osd.layout custom
voxtype config set output.notification.on_recording_stop false

# 4. Restart + verify
if [ "$RESTART" = true ]; then
  systemctl --user restart voxtype
  sleep 5
  if [ "$(voxtype status 2>/dev/null)" = "idle" ]; then
    echo "voxtype restarted and idle. Press your dictation hotkey to see the eye."
  else
    echo "WARNING: voxtype status is '$(voxtype status 2>/dev/null)' (expected idle). Check: journalctl --user -u voxtype -n 30"
    exit 1
  fi
else
  echo "Skipping restart (--no-restart). Run: systemctl --user restart voxtype"
fi

echo "Done. Revert any time with ./uninstall.sh"
