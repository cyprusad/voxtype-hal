#!/bin/bash
# voxtype-hal uninstaller — clean revert to the pre-HAL setup.
#
#   ./uninstall.sh [--keep-files] [--no-restart]
#
# Revert order (first available wins):
#   1. Restore the newest ~/.config/voxtype/config.toml.pre-hal-* backup
#   2. Otherwise restore the exact values in .hal-backup.env
#   3. Otherwise reset the five touched keys to voxtype built-in defaults
# Then restarts voxtype and verifies. Removes the installed package copy
# unless --keep-files is passed. The repo itself is untouched.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/voxtype/osd/voxtype-hal"
CONFIG="${HOME}/.config/voxtype/config.toml"
RESTART=true
KEEP_FILES=false

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET_DIR="$2"; shift 2 ;;
    --keep-files) KEEP_FILES=true; shift ;;
    --no-restart) RESTART=false; shift ;;
    -h|--help)
      echo "Usage: ./uninstall.sh [--target DIR] [--keep-files] [--no-restart]"
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
need voxtype
need systemctl

restore_key() {  # $1 = key, $2 = recorded value
  if [ "$2" = "__UNSET__" ]; then
    voxtype config unset "$1" || true
  else
    voxtype config set "$1" "$2"
  fi
}

echo "== voxtype-hal: reverting to pre-HAL setup =="

BACKUP="$(ls -t "${CONFIG}".pre-hal-* 2>/dev/null | head -n 1 || true)"
if [ -n "$BACKUP" ]; then
  cp "$BACKUP" "$CONFIG"
  echo "Restored config backup: $BACKUP"
elif [ -f "${TARGET_DIR}/.hal-backup.env" ]; then
  # shellcheck disable=SC1090
  while IFS='=' read -r key value; do
    case "$key" in \#*|"") continue ;; esac
    restore_key "$key" "$value"
  done < "${TARGET_DIR}/.hal-backup.env"
  echo "Restored original values from .hal-backup.env"
else
  voxtype config set osd.frontend gtk4
  voxtype config set osd.style default
  voxtype config unset osd.palette || true
  voxtype config set osd.layout compact
  voxtype config set output.notification.on_recording_stop true
  echo "No backup found; reset OSD keys to voxtype defaults"
fi

if [ "$KEEP_FILES" = false ] && [ -d "$TARGET_DIR" ]; then
  if grep -q 'name = "voxtype-hal"' "$TARGET_DIR/voxtype-osd.toml" 2>/dev/null; then
    rm -rf "$TARGET_DIR"
    echo "Removed installed package: $TARGET_DIR"
  else
    echo "Not removing $TARGET_DIR (does not look like a voxtype-hal install)"
  fi
fi

# Opt out of auto-apply: the bundled Omarchy service
# (io.github.cyprusad.voxtype-hal) checks this sentinel and stays idle
# while it exists, so a manual revert survives shell restarts.
# install.sh removes it again.
mkdir -p "$(dirname "$TARGET_DIR")"
touch "$(dirname "$TARGET_DIR")/.hal-disabled"
echo "Auto-apply disabled (sentinel: $(dirname "$TARGET_DIR")/.hal-disabled)"

if [ "$RESTART" = true ]; then
  systemctl --user restart voxtype
  sleep 5
  echo "voxtype status: $(voxtype status 2>/dev/null || echo UNKNOWN)"
else
  echo "Skipping restart (--no-restart). Run: systemctl --user restart voxtype"
fi

echo "Done. Reinstall any time with ./install.sh (repo: $REPO_DIR)"
