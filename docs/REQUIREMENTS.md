# Project requirements

This document is the authoritative product contract for the `orangepi5pro-gaming` profile. A build recipe may be technically successful and still fail this contract.

## Target hardware and operating model

- Orange Pi 5 Pro with RK3588S and 4 GB RAM.
- Geekworm 515 enclosure with its included fan is the reference cooling configuration.
- Television/monitor appliance usage with 16:9 as the ordinary presentation target, while allowing each emulator to apply its own aspect-ratio policy.
- Maximum-performance policy is preferred over power saving. The practical visual target is the highest graphics quality that remains stable around 1080p60; 4K is required where the workload and display permit it, especially media and Moonlight validation.
- UK defaults: `en_GB.UTF-8`, `Europe/London`, GB keyboard and GB Wi-Fi regulatory domain.

## Required user experience

- Boot directly into a controller-first Gamescope/ES-DE gaming session through greetd.
- Accept any controller presented through native Linux input; no vendor allowlist may be required for normal operation.
- Treat the EasySMX X20 over USB, 2.4 GHz receiver and Bluetooth as the reference acceptance device, not as the only supported controller.
- Guide/Home + Start toggles the on-screen keyboard. A stick-controlled mouse must make non-game applications usable without a physical mouse.
- Provide a lightweight Labwc desktop from ES-DE. A nonzero Gamescope failure must preserve the controller shell by launching ES-DE directly under Labwc; Direct Gaming Mode must also be manually selectable for comparison/recovery.
- Expose network setup, audio selection, Brave, Firefox, Stremio, Moonlight, desktop mode, restart, reboot and shutdown through ES-DE's Ports collection.
- Autodetect the connected display and use its current/preferred highest usable mode. Enable HDR only when the active output advertises HDR static metadata.
- Provide both HDMI/DisplayPort and Bluetooth audio. HDMI is the initial default; the user may change output at runtime.
- Automount ordinary removable filesystems read/write and discover the documented USB ROM directory layout.

## Mandatory applications and services

- Native ARM64 Stremio Linux shell, not an Android container.
- Brave as the default browser and Firefox as an installed alternative; both must be launchable and operable from the controller-first environment.
- Moonlight Qt with hardware decoding forced and output/HDR settings derived at launch.
- OpenCode and Kitty retained for local troubleshooting/development.
- NetworkManager, BlueZ, PipeWire/WirePlumber, UDisks/udiskie and the hardware/validation utilities shipped by the profile.
- Steam visible as an explicitly experimental, on-demand entry. Steam success cannot block the stable image.

## Emulator coverage

The final image must expose standalone native ARM64 emulators for:

- PlayStation, PlayStation 2 and PSP;
- Nintendo 64 and Dreamcast;
- GameCube and Wii;
- Game Boy, Game Boy Color and Game Boy Advance;
- Nintendo DS and Nintendo 3DS;
- NES and SNES.

RetroArch/libretro is intentionally outside the current architecture. See `EMULATION.md` for exact mappings and test expectations.

## Hard release gates

The following must pass on the real Orange Pi, not merely inside QEMU or the build host:

1. Cold boot, correct display output, Panthor/PanVK rendering and stable Gamescope → ES-DE startup.
2. Controller-first navigation, gamepad mouse and OSK, including the EasySMX X20's three transports.
3. Native Stremio playback with affirmative `v4l2request-copy` evidence from Stremio's embedded libmpv process. A working UI, standalone mpv success, software decoding, blank video or white video is not sufficient.
4. H.264, HEVC 8-bit, HEVC Main10/HDR10, VP9 and AV1 probe coverage, including the bundled 4K probes.
5. Moonlight hardware-decoded streaming at the display mode detected at launch. A 4K display therefore requires a real 4K stream test.
6. Representative content in every emulator family with controller input, video and audio proven.
7. HDMI/DisplayPort audio and user-selected Bluetooth audio.
8. Wi-Fi, Bluetooth, removable storage, both browsers and Labwc fallback.
9. Sustained 4 GB memory pressure and thermal stability under the maximum-performance policy.
10. Zero unexplained failures in the generated `opi-validation-report`.

## Storage phases

- Development and initial acceptance: boot and root filesystem remain on SD.
- Finalized image: boot remains on SD while the root filesystem moves to Btrfs on NVMe.
- After eMMC purchase and validation: boot moves to eMMC, root remains Btrfs on NVMe, and the SD card can be removed.
- Before final approval, NVMe access is strictly read-only inventory/SMART. The builder must never mount, partition, format or migrate it.

## Security and maintenance policy

- Security-only unattended Ubuntu updates are enabled; automatic reboot is disabled.
- Provide an attended on-device updater for signed same-release Armbian, Ubuntu and third-party APT repositories, with simulation, free-space/process guards, package-version records and pre/post core health checks.
- Treat this as a rolling-maintained appliance within Ubuntu Resolute, not an unsupported rolling distribution. Distribution-suite upgrades are blocked until separately built and validated as a new project generation.
- Keep source-built Stremio, its dedicated FFmpeg/mpv, Moonlight and source-built emulators pinned until a signed project-bundle update channel can preserve their ABI, runtime-closure and hardware gates.
- SSH server and socket are disabled by default. The OpenSSH client remains available.
- Suspend and hibernate are disabled for appliance predictability.
- No credentials, plaintext passwords, password hashes, ROMs, copyrighted BIOS files or generated images belong in Git.
- Source tags are resolved to commits, build outputs are hashed, and a source lock/manifest accompanies the image.

## Component criticality

- `core`: boot/graphics/session recovery, controller input/OSK, native Stremio hardware decoding, Moonlight, networking and audio. A core failure rejects the appliance immediately.
- `required`: Gamescope, the complete specified emulator catalogue, Firefox, CEC and removable-storage support. These may be diagnosed after an MVP first boot, but every item must pass before the image is final.
- `experimental`: Steam ARM64 and GE-Proton. They remain visible and testable but cannot block the stable appliance.

## Explicit non-goals

- Kodi, Lumera, an Android compatibility container, RetroArch/libretro, XFCE, LightDM, Samba, SFTP and automatic backup services.
- Automatic NVMe repartitioning or migration.
- Treating Steam ARM64 as production-supported.
- Bundling ROMs, keys, firmware or BIOS material the user must legally supply.
- Claiming compatibility with every game. The requirement is that each emulator is installed, launchable and proven with representative legal test content; per-title compatibility remains an upstream concern.

## Definition of final

The image becomes final only when a fresh repository build completes, offline image QA passes, the image is flashed to separate test media, all hard release gates pass on the Orange Pi 5 Pro, Stremio hardware decoding is proven inside Stremio, the emulators and rest of the system are functional, and ordinary operation is controller-accessible. Until then every version is a development generation.
