#!/bin/bash
# voxtype-hal lens color switcher — no restart needed, the eye picks the
# new hue live (within ~3s) via assets/lens.json.
#
#   ./lens.sh hal|system|amber|ice|violet|#RRGGBB
#
# Modes: hal = classic HAL red (default), system = follow the active
# Omarchy theme, anything else = fixed hue. The choice survives
# reinstalls (install.sh never overwrites an existing lens.json).
set -euo pipefail

LENS_FILE="${HOME}/.config/voxtype/osd/voxtype-hal/assets/lens.json"

usage() { echo "Usage: $0 hal|system|amber|ice|violet|#RRGGBB" >&2; exit 1; }

arg="${1:-}"
mode="custom"
color=""
case "$arg" in
  hal) mode="hal"; color="#FF2D2D" ;;
  system|theme) mode="theme"; color="#FF2D2D" ;;
  amber) mode="custom"; color="#FFB84D" ;;
  ice) mode="custom"; color="#66C7FF" ;;
  violet) mode="custom"; color="#B48CFF" ;;
  \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) mode="custom"; color="$arg" ;;
  *) usage ;;
esac

mkdir -p "$(dirname "$LENS_FILE")"
printf '{"mode":"%s","color":"%s"}\n' "$mode" "$color" > "$LENS_FILE"
echo "Lens -> $mode $color (live in ~3s while dictating)"
