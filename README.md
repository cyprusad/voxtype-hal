# voxtype-hal — HAL 9000 eye for Voxtype dictation

A shareable Voxtype Quickshell style package that replaces the default
waveform bar with a **HAL 9000-style red eye** while dictating.

Everything lives inside the eye — nothing floats over your desktop:

- **Red lens** brightens with voice energy, hot white core when you're loud
- **Arc ring** around the lens = live volume level, with a held-peak tick
- **Mini bars** in the lower lens = scrolling sound-wave history
- **Status pill** at the top of the lens = elapsed time while speaking,
  flips to amber `Transcribing…` while the model works
- Soft halo glow + dark scrim so it separates from busy windows behind it

## Install (one command)

```bash
git clone <this-repo> ~/.config/voxtype/osd/voxtype-hal-src
~/.config/voxtype/osd/voxtype-hal-src/install.sh
```

Or from a checkout anywhere:

```bash
./install.sh [--target DIR] [--no-restart]
```

The installer:

1. Copies the style package into `~/.config/voxtype/osd/voxtype-hal/`
2. Backs up `~/.config/voxtype/config.toml` to
   `config.toml.pre-hal-<timestamp>` (kept forever, never overwritten)
   and records the exact original OSD values
3. Switches `[osd]` to `quickshell` + this package and silences the
   "recording stopped" desktop notification (the eye shows state now)
4. Restarts voxtype and verifies the daemon is idle-ready

Re-running the installer is safe (idempotent) — it re-applies the same state.

Requirements: `voxtype` with the Quickshell OSD backend (`qs` or
`voxtype-osd-quickshell` on PATH). Tested with voxtype 1.0.x on Omarchy/Hyprland.

## Uninstall (clean revert)

```bash
./uninstall.sh [--keep-files] [--no-restart]
```

Restores the newest `config.toml.pre-hal-*` backup (falling back to the
recorded original values, then to voxtype built-in defaults), removes the
installed package copy, restarts voxtype. Your old waveform OSD comes back
exactly as it was.

## Files

| File | Purpose |
|------|---------|
| `Hal.qml` | The eye. Custom QML, runs trusted inside the voxtype OSD host |
| `voxtype-osd.toml` | Style package manifest (red palette, custom layout) |
| `install.sh` | One-click install with backup |
| `uninstall.sh` | One-click clean revert |

## Customization

Tweak colors in `voxtype-osd.toml` (`[colors]`), behavior in `Hal.qml`
(it's plain QtQuick + Canvas — `qmllint Hal.qml` to validate), then
re-run `./install.sh` and restart voxtype.

## License

MIT — same as Voxtype.
