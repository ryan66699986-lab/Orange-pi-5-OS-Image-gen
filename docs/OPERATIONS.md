# Runtime operations

## Normal startup

greetd uses an initial session for `ryan`, reads `/etc/opi/session-mode`, and defaults to `/usr/local/bin/opi-gaming-session`. Gamescope launches ES-DE while `gamepad-osk` and udiskie run as supervised children. A nonzero Gamescope failure launches ES-DE directly under Labwc; a normal exit enters the Labwc desktop.

At later logins, tuigreet remains available as the recovery login/session selector. The password entered during image construction is the local `ryan` account password.

## Controller-only navigation

- Use the controller normally in ES-DE and emulators.
- Press Guide/Home + Start to toggle the OSK.
- Use the configured mouse stick for applications without native gamepad navigation.
- The Ports collection exposes Stremio, Moonlight, browsers, network, audio, desktop mode and power actions.

A physical keyboard/mouse remains useful for debugging but is not part of the definition of ordinary usability.

## Session switching

From a terminal:

```bash
gaming-mode
direct-gaming-mode
desktop-mode
```

These commands set the persistent mode and restart greetd, ending the current graphical session. Equivalent entries are available in ES-DE. To change the mode without immediately restarting the session:

```bash
sudo opi-set-session gaming
sudo opi-set-session direct
sudo opi-set-session desktop
```

## Network and Bluetooth

- `Network Setup` opens NetworkManager's connection editor.
- The Labwc tray exposes NetworkManager and Blueman applets.
- The GB regulatory-domain service runs after NetworkManager and retries until `iw reg get` reports GB.
- Bluetooth audio devices should be paired through Blueman; game controllers may also be paired with Blueman or `bluetoothctl` during diagnosis.

## Audio

HDMI/DisplayPort is selected once when the first user session successfully exposes an HDMI/DP sink. The selection is recorded in `~/.local/state/opi/audio-initial-default.env`; the service then becomes a no-op, so later Bluetooth or HDMI choices remain the user's. `Audio Settings` opens `pavucontrol`. Useful inspection commands:

```bash
wpctl status
wpctl get-volume @DEFAULT_AUDIO_SINK@
opi-audio-check
```

The final command proves capability, not listening quality; verify real audio through both paths.

## Removable storage and ROMs

udiskie mounts supported removable filesystems through UDisks. Put games under `ROMs/<system>` on the device as documented in `EMULATION.md`. To request an immediate rescan:

```bash
opi-rom-scan
```

The scanner creates symlinks only and does not copy or delete source ROM files. It may delete stale symlinks in the local `~/ROMs` tree when the source is no longer present.

## Validation and diagnostics

| Command | Purpose |
|---|---|
| `opi-validate` | Aggregate live system checks; returns non-zero for hard failures |
| `opi-validation-report [path]` | Run aggregate checks and retain a timestamped report |
| `opi-media-hwtest` | DRM, Vulkan, V4L2 device and basic decoder inventory |
| `opi-stremio-hwcheck` | Headless bundled codec probes through dedicated mpv/FFmpeg |
| `opi-stremio-hwcheck --visible` | Render the same probes through the graphical path |
| `opi-stremio-session-check` | Inspect actual Stremio playback evidence |
| `opi-moonlight-hwcheck` | Check forced-hardware policy and dedicated linkage |
| `opi-moonlight-session-check` | Prove an actual detected-mode hardware-decoded stream |
| `opi-controller-check` | Enumerate readable Linux-input joystick devices |
| `opi-audio-check` | Check HDMI/DP sink and Bluetooth audio capability |
| `opi-gpu-check` | Prove PanVK hardware Vulkan and reject software rendering |
| `opi-cec-check` | Prove CEC adapter plus Linux remote-input integration |
| `sudo opi-nvme-check` | Read-only NVMe inventory and SMART data |
| `opi-appliance-health [--strict]` | Classify core, required and experimental appliance health |
| `sudo opi-update check` | Refresh metadata, simulate same-release upgrades and show pinned project components |
| `sudo opi-update apply` | Attended same-release package maintenance with pre/post health checks |

## Important logs and state

| Path | Contents |
|---|---|
| `~/.local/state/opi/gamescope.log` | Gamescope stderr and fallback reason |
| `~/.local/state/opi/gamepad-osk.log` | OSK daemon output in Gaming Mode |
| `~/.local/state/opi/udiskie.log` | Gaming Mode removable-storage output |
| `~/.local/state/opi/stremio.log` | Native Stremio/libmpv playback evidence |
| `~/.local/state/opi/moonlight.log` | Moonlight wrapper/session output |
| `~/.local/state/opi/moonlight-display.env` | Selected output, resolution, refresh and HDR detection |
| `~/.local/state/opi/audio-initial-default.env` | One-time HDMI/DP default-selection record |
| `/tmp/opi-*.log` | Most recent helper-specific transient evidence |
| `/opt/opi-build-meta/` | Build manifest, source locks and codec probes installed in the image |
| `/var/log/opi-update/` | Update simulations, package inventories and post-update results |

## Updates

Security updates are installed automatically without automatic reboot. For ordinary Armbian, Ubuntu, Brave, Firefox and other APT-managed maintenance, switch to Labwc Desktop Mode, close gaming/media/browser applications, then use:

```bash
sudo opi-update check
sudo opi-update apply
```

`apply` repeats the simulation, displays and respects package holds, requires at least 1.5 GiB free, requires the literal confirmation `UPDATE`, records package versions before/after, runs `dpkg --audit`, and repeats core health checks. It never performs `dist-upgrade`, `full-upgrade` or `do-release-upgrade`; `/etc/update-manager/release-upgrades` is set to `Prompt=never`. Change Armbian's firmware hold policy separately and deliberately through its documented update controls—`opi-update` does not silently unhold boot-critical packages.

This is rolling maintenance within Ubuntu Resolute, not a rolling distribution. APT updates Armbian kernel/firmware/BSP, Ubuntu packages, both browsers and distro-packaged emulators. Source-built Stremio, its dedicated FFmpeg/mpv, Moonlight and the source-built emulator artifacts remain pinned in `/opt/opi-build-meta/versions.lock.json`. They must eventually be updated through a separately signed, board-tested project bundle; `opi-update` reports this boundary instead of silently substituting incompatible upstream binaries.

Do not manually change the Ubuntu suite on a known-good appliance. Armbian documents distribution upgrades as outside its supported scope, and a suite transition can invalidate the custom media ABI, Mesa/PanVK, kernel and browser repository contract.

## Recovery principles

- Keep the last known-good SD image until the replacement passes cold boot and validation.
- Prefer Direct Gaming Mode when Gamescope alone fails, Desktop Mode for maintenance, and a TTY if Labwc also fails.
- Do not erase validation logs before collecting them.
- Do not run storage migration as a troubleshooting step.
- Steam failures are isolated/experimental; do not change the production media or graphics stack merely to make Steam work.
