# Validation and release acceptance

Validation has four layers:

1. repository/static checks;
2. successful Armbian image generation;
3. offline inspection of the completed raw image;
4. actual Orange Pi 5 Pro hardware validation.

Only layer 4 can prove HDMI/display behavior, GPU acceleration, onboard wireless, controllers, thermal stability and RK3588 hardware video decoding.

## Layer 1 — repository/static

Run `./tools/check.sh`. It syntax-checks source scripts, generated shell/config payloads, embedded container programs and embedded Python; verifies source/build/runtime invariants; exercises regression fixtures; and rejects forbidden NVMe mutation commands. A PASS means the repository is internally consistent, not that external sources or hardware work.

## Layer 2 — full build

The build must start from a fresh workspace and finish every stage without a suppressed mandatory error. Retain:

- complete build log;
- repository commit;
- `versions.lock.json`;
- artifact/download hashes;
- image SHA-256;
- terminal success summary.

Any failed target-root assertion invalidates the candidate even if the `.img` file already exists.

## Layer 3 — offline raw-image QA

The final stage mounts the raw image through controlled loop devices and checks packages, commands, launchers, permissions, media libraries, browser sources, controller config, kernel arguments, session mode, systemd masks, helper files and NVMe installer presence. Do not distribute an image if this stage did not run to completion.

## Layer 4 — board acceptance sequence

Flash separate test media, verify its hash, keep a recovery SD, and execute the following order. Ordering matters: later application symptoms depend on earlier kernel/display/input foundations.

### 1. Boot and base health

```bash
uname -a
cat /proc/device-tree/model
systemctl --failed
opi-validation-report
```

Cold boot at least three times. Confirm greetd reaches ES-DE without keyboard intervention and that Gamescope has not silently fallen back to Labwc.

### 2. GPU, display and thermal baseline

```bash
ls -l /dev/dri
vulkaninfo --summary
opi-media-hwtest
```

Test at least the primary intended display and one materially different display/mode when available. Verify correct preferred/current resolution, 16:9 presentation, overscan, hotplug recovery, HDR detection only on HDR-capable outputs, console blanking policy and no Panthor/PanVK resets in `journalctl -k`.

### 3. Controller and controller-only UI

Run `opi-controller-check` with each available controller, then use `evtest` to exercise every button, stick, trigger and D-pad. The EasySMX X20 must be tested over USB, the 2.4 GHz receiver and Bluetooth. Verify Guide+Start toggles the OSK and that the controller mouse can operate Brave, Firefox, network and audio dialogs.

Also verify reconnect after controller power-cycle, controller use after emulator exit, and that multiple attached input devices do not steal or duplicate the primary mapping. Test force feedback where the transport and application expose it.

### 4. Native Stremio media gate

Run:

```bash
opi-stremio-hwcheck
opi-stremio-hwcheck --visible
```

The bundled H.264, HEVC 8-bit, HEVC Main10/HDR10, VP9 and AV1 probes—including the 4K set—must all decode through `v4l2request-copy`. Then play representative H.264 and HEVC/Main10 content inside Stremio and run:

```bash
opi-stremio-session-check
```

The session helper must find affirmative evidence from Stremio's embedded libmpv process. A working UI, standalone mpv success, software-decoded playback, or blank/white video is a failure. Inspect colour, scaling, frame pacing and audio sync, and retain `~/.local/state/opi/stremio.log`.

### 5. Moonlight gate

Launching Moonlight runs `opi-moonlight-display-auto`, which records the active output's current/preferred resolution and refresh rate and enables HDR only when the active connector's EDID advertises HDR static metadata.

```bash
opi-moonlight-hwcheck
# complete a real stream at the detected mode
opi-moonlight-session-check
```

The session helper requires both the exact detected resolution and an affirmative `hardware-accelerated` decoder record from the pinned Moonlight binary. On a 4K screen this remains a real 4K gate. Check controller forwarding, audio, HDR when detected, reconnect/exit behavior and sustained streaming rather than only reaching the host desktop.

### 6. Audio, wireless and removable storage

Run `opi-audio-check` while HDMI/DisplayPort is attached. It requires an HDMI/DisplayPort PipeWire sink, a Bluetooth controller and the PipeWire Bluetooth plugin. Confirm HDMI is the initial default, then select a Bluetooth sink and verify real playback follows the user's selection.

Test Wi-Fi join/reconnect and Bluetooth controller/audio reconnection. Mount representative exFAT, NTFS, FAT and ext filesystems where available; confirm read/write behavior, USB ROM discovery and safe unmount. Run the read-only NVMe check but perform no migration.

### 7. Emulator matrix

Follow `EMULATION.md`. Launch representative legal content for every system through ES-DE, not only the emulator directly. Record renderer, internal resolution, controller behavior, audio, observed frame rate, saving and exit-to-ES-DE. Test demanding systems long enough to expose throttling or memory pressure. Test RetroAchievements sign-in where safely supported.

### 8. Desktop and browser recovery

Enter Labwc from ES-DE, launch Kitty/OpenCode, file manager, both browsers, network and audio tools, then return to Gaming Mode. Verify controller mouse/OSK text entry and browser audio/video. Confirm Gamescope fallback is usable but do not intentionally leave a real Gamescope fault unresolved.

### 9. Memory and thermal soak

Run demanding emulation, Stremio 4K and Moonlight sessions long enough to reach thermal equilibrium. Record temperature, throttling/kernel messages, memory, zram/swap activity and earlyoom events. The Geekworm 515 fan must operate. A test that survives only by sustained disk-swap thrashing is not acceptable.

## Aggregate report

Run and retain:

```bash
opi-validation-report
```

The installed NVMe can be checked without changing it:

```bash
sudo opi-nvme-check
```

Do not mount, partition, format, or migrate the OS to NVMe until the image passes all release gates. Follow `STORAGE.md` afterwards.

## Evidence record

For every candidate, archive a compact record containing:

| Field | Required value |
|---|---|
| Repository/image | commit, VERSION, image filename and SHA-256 |
| Sources | generated lock and artifact hashes |
| Hardware | board/RAM, cooling, SD, NVMe identity and connected display |
| Display | output name, mode/refresh, HDR detected/result |
| Stremio | probe output, visible result, session-check output and content codecs |
| Moonlight | detected policy file, stream mode, session-check output and host configuration |
| Controllers | model/transport, input/OSK/mouse/rumble result |
| Audio | HDMI/DP and Bluetooth device/result |
| Emulators | system, test content, renderer/resolution/performance/result |
| Stability | duration, peak temperature, memory/swap and kernel/systemd failures |
| Exceptions | exact known limitation, owner and whether it blocks release |

## Pass/fail policy

- All hard requirements must pass; no averaging or majority rule.
- A WARN requires an explanation and disposition in the evidence record.
- Steam failure is non-blocking unless it destabilizes the rest of the system.
- A software-decoding fallback is never acceptable for Stremio or Moonlight.
- A test performed through standalone mpv cannot replace actual Stremio playback.
- Repeating only the failed test is insufficient after kernel, Mesa, media, session or package-manifest changes; rerun the dependent suite.
- Storage migration happens only after the SD candidate is approved and does not itself promote a candidate to final until the new topology is cold-booted and revalidated.
