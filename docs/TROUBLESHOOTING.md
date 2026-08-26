# Troubleshooting and failure triage

## Golden rule for build failures

Treat a failed Armbian workspace as diagnostic-only. Preserve the generated diagnostic bundle/log, fix the canonical repository, and start the next attempt from a completely fresh versioned workspace. Never resume, repair or reuse a failed Armbian tree or its artifacts.

## Find the first real failure

Armbian and Docker print cleanup errors after a command has already failed. Diagnose in this order:

1. Locate the earliest explicit project `FAIL`, `ERROR`, `die` message or non-zero command immediately before Armbian's stack trace.
2. Identify the responsible layer: host preflight, source resolution, isolated ARM64 recipe, artifact merge, Armbian kernel/rootfs, target customization or offline image QA.
3. Confirm whether the failed assertion describes the actual state or is itself incorrect.
4. Classify later unmount, Docker deletion and cleanup messages as consequences unless independent evidence says otherwise.
5. Change the source repository and add a regression check that would have caught the defect before the same point.

Never weaken a hard gate solely because it stopped a long build. The V3.19 gamepad failure was fixed by proving the parser wrong against upstream syntax and then testing the corrected parser; the requirement itself remained enabled.

## Diagnostic bundle

Failed builds place a versioned bundle under `~/opi5pro-images/failed-v<version>-<timestamp>/`. Retain at minimum:

- complete `build.log`;
- generated `versions.lock.json` if source resolution completed;
- manifest/hashes produced before the stop;
- the final console output and failure timestamp;
- repository commit used for the run.

Do not attach plaintext passwords, tokens, private ROM/BIOS paths or other credentials.

## Common build signatures

| Signature | Interpretation | Action |
|---|---|---|
| Host disk/Docker/loop preflight fails | Host is not ready; no image work is trustworthy | Restore disk space, Docker access or privileged loop support, then rerun |
| ARM64 binfmt/QEMU fails | Isolated native recipes cannot execute | Repair binfmt/QEMU registration; do not bypass architecture checks |
| Source tag/commit/asset missing | Pin moved, was mistyped or upstream changed | Review upstream; update pin/compatibility assertion deliberately |
| Package solver fails | Package renamed/removed or wrong repository/component | Confirm Resolute ARM64 package name; update manifests and target gates together |
| `gcc`/header/CMake policy failure | Isolated build dependency or upstream compatibility issue | Fix the owning recipe and add an early/static regression |
| `ldd` reports `not found` in merged preflight or target | Build-container dependency was not packaged for runtime | Add the runtime package/artifact manifest and target/offline assertions; do not bypass the V3.22 core/AppImage closure gate |
| Wrong `/opt/opi/media` linkage | Application silently resolved distro FFmpeg/mpv | Fix pkg-config/library/RUNPATH; never accept generic linkage |
| Target-root gate fails | Assembled image violates contract, or validator is wrong | Inspect actual target data and upstream format before changing either |
| Offline image QA fails | Raw image differs from assembled expectations | Treat as release-blocking; do not distribute the image |
| Armbian U-Boot branch-shaped tag probes fail then recover | Resolver probing noise when valid tag resolution follows | Document/classify; no fix unless final resolution fails |
| `invoke-rc.d` denied during rootfs install | Expected service suppression in offline/chroot package installation | Ignore only when package configuration succeeds |
| Compiler warnings in pinned third-party code | Potential upstream issues, not automatically build failures | Review new/different warnings; successful gates do not erase runtime testing |

## Password prompt problems

The password is for the future `ryan` account in the Orange Pi image, not GitHub. Input is intentionally invisible. Both reads must come from `/dev/tty`; the repository statically checks this because an earlier builder consumed stage-list input instead of the keyboard.

## Gaming Mode fails or returns to Desktop Mode

Inspect:

```bash
cat ~/.local/state/opi/gamescope.log
journalctl --user -b
journalctl -u greetd -b
vulkaninfo --summary
ls -l /dev/dri
```

Automatic Labwc fallback is a recovery feature, not proof that Gaming Mode is acceptable. A final image requires stable Gamescope/ES-DE.

## Controller or OSK failure

```bash
opi-controller-check
ls -l /dev/uinput
id
sudo evtest
cat ~/.local/state/opi/gamepad-osk.log
```

Confirm uinput/UHID modules, `ryan` group membership, readable event nodes and the exact `/etc/gamepad-osk/config`. Test the controller outside the emulator before creating emulator-specific mappings.

## Stremio problems

Run in this order:

```bash
opi-media-hwtest
opi-stremio-hwcheck
opi-stremio-hwcheck --visible
# play representative content inside Stremio
opi-stremio-session-check
```

Interpretation:

- Headless failure: decoder/media stack or kernel device problem.
- Headless pass, visible fail: display/GPU/frame-presentation problem.
- Both probes pass, session check fails: Stremio did not use the intended embedded libmpv path or the tested content selected another path.
- Session check passes but video is blank/white: still a failure; affirmative log evidence cannot replace visual output.

Collect `/dev/video*`, `v4l2-ctl`, `/dev/dri`, Vulkan summary, the Stremio state log and relevant `journalctl` output.

## Moonlight problems

Run `opi-moonlight-hwcheck`, launch Moonlight once, inspect `~/.local/state/opi/moonlight-display.env`, complete a stream, then run `opi-moonlight-session-check`. Do not reduce the expected resolution in the evidence file to manufacture a pass. On a 4K display the accepted stream must be 4K.

## Audio problems

```bash
wpctl status
bluetoothctl list
systemctl --user status pipewire pipewire-pulse wireplumber
opi-audio-check
```

Capability PASS does not prove the correct sink is selected. Use `pavucontrol`/`wpctl`, test HDMI first, then select the Bluetooth sink and test again.

## Memory and thermal instability

```bash
free -h
swapon --show
zramctl
systemctl status opi-swapfile earlyoom opi-performance
cat /sys/class/thermal/thermal_zone*/temp
```

Confirm the Geekworm fan operates and that performance governors do not cause sustained throttling. Do not hide an out-of-memory defect by disabling the release workload or by allowing unlimited swap thrashing.

## NVMe problems

Before migration, use only `sudo opi-nvme-check`, `lsblk` and read-only kernel/SMART inspection. If detection or SMART fails, stop. Formatting is not a diagnostic step. After migration, use the topology/rollback procedure in `STORAGE.md`.
