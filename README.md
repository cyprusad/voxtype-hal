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

## Usage

Press your Voxtype dictation hotkey and speak. The eye appears
bottom-center: the lens brightens with your voice, the ring shows your
level, the pill shows elapsed time. Release the key and the pill flips to
amber `Transcribing…` until the text lands at your cursor, then the eye
fades away.

## Configure

Lens colors live in `voxtype-osd.toml` under `[colors]` (`accent`,
`recording`, `foreground`…). Behavior lives in `Hal.qml` (plain QtQuick +
Canvas — validate with `qmllint Hal.qml`). After editing, re-run
`./install.sh` and restart voxtype:

```bash
./install.sh
```

To bring back the "recording stopped" desktop notification alongside the
eye:

```bash
voxtype config set output.notification.on_recording_stop true
systemctl --user restart voxtype
```

## Omarchy plugin

This repo is also a valid Omarchy shell plugin
(`omarchy plugin validate` clean):

- **ID:** `io.github.cyprusad.voxtype-hal` (`service` kind)
- Install: `omarchy plugin add <repo-url> --enable`
- The service auto-applies the eye on shell start (idempotent —
  no-op when already active, verified in the shell log as
  `[voxtype-hal] ALREADY`).
- It respects the opt-out sentinel `~/.config/voxtype/osd/.hal-disabled`
  (created by `./uninstall.sh`, cleared by `./install.sh`).
- `omarchy plugin remove io.github.cyprusad.voxtype-hal` stops future
  auto-apply; run `./uninstall.sh` for the full Voxtype revert.

## Remove

Full revert (eye gone, old waveform back exactly as it was). If you
installed via `omarchy plugin add`, the plugin folder already contains
this repo — run:

```bash
~/.config/omarchy/plugins/io.github.cyprusad.voxtype-hal/uninstall.sh
omarchy plugin remove io.github.cyprusad.voxtype-hal --yes
```

From a repo checkout, it's just:

```bash
./uninstall.sh [--keep-files] [--no-restart]
```

What `uninstall.sh` does: restores the newest `config.toml.pre-hal-*`
backup (falling back to the recorded original values, then to voxtype
built-in defaults), removes the installed package copy, sets the
opt-out sentinel so the service never re-applies, and restarts voxtype.

Prefer no CLI? Remove the shell side in the Omarchy menu
(Setup → Plugins → Remove), then run the `uninstall.sh` line above for
the Voxtype side. Note: removing only the shell plugin is safe but not
a revert — the eye keeps working until `uninstall.sh` runs.

## Files

| File | Purpose |
|------|---------|
| `Hal.qml` | The eye. Custom QML, runs trusted inside the voxtype OSD host |
| `voxtype-osd.toml` | Style package manifest (red palette, custom layout) |
| `manifest.json` | Omarchy plugin manifest (`io.github.cyprusad.voxtype-hal`) |
| `Service.qml` | Omarchy headless service: idempotent auto-apply on shell start |
| `install.sh` | One-click install with backup |
| `uninstall.sh` | One-click clean revert |
| `LICENSE` | MIT |

## License

MIT — see `LICENSE`.
