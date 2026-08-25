# Project status

## Current generation: V3.20

V3.20 is the active build under test.

V3.19 ran for 48,386 log lines and reached final target-root customization. It proved the V3.19 Brave-key correction, built all ten native ARM64 artifacts, passed Azahar's 64 tests, built the Armbian kernel/root filesystem and installed V3.18's previously missing Moonlight libraries in the target. It then stopped at the controller-mouse assertion even though the pinned upstream `gamepad-osk` configuration already contained `enabled = true` with an inline explanatory comment. The old `awk` expression rejected any text after `true`. V3.20 normalizes the target setting and validates both the normalized and upstream-commented forms in the target root and completed image.

V3.18 stopped at its deliberately early Brave/Firefox repository preflight, before native compilation. The builder incorrectly compared Brave's downloaded release APT keyring with the `D161…F691` key used to verify Brave's separate installer script. The official release APT keyring instead contains three current primary keys. V3.19 validates that exact primary-key set in the early ARM64 container and again in the assembled target root, then relies on APT's repository-metadata signature verification and successful ARM64 package installation as the functional proof.

The completed V3.16 run compiled all native artifacts, built the Armbian kernel/root filesystem and entered final target customization. It then correctly stopped when Moonlight's `ldd` gate found two absent runtime libraries: `libSDL2_ttf-2.0.so.0` and `libQt6QuickControls2.so.6`. Both development packages had been present in the isolated Moonlight build container, so compilation and build-container linkage passed, but the corresponding runtime packages were not copied into the target package manifest. V3.17 inherited that omission before the V3.16 log arrived.

V3.18 explicitly includes `libsdl2-ttf-2.0-0` and `libqt6quickcontrols2-6`, records them in Moonlight's runtime manifest, and repairs generic dependency collection for merged-`/usr` systems where `ldd` and the dpkg database can use different `/lib` and `/usr/lib` spellings. Static, target-root and offline-image gates now require the packages, resolved links and library files.

V3.15 proved the Snes9x GCC 15 compatibility repair and completed native builds of Snes9x, Stremio, PPSSPP, ES-DE and gamepad-osk. It also compiled and linked Moonlight 6.1.0 against the dedicated V4L2 Request FFmpeg libraries, passed the binary RUNPATH, dependency and decoder-evidence gates, then stopped while creating its launcher because `/out/rootfs/usr/local/bin` had not been created. V3.16 creates that directory explicitly and validates the installed launcher immediately.

V3.17 retains that Moonlight packaging repair and expands the early gates around the completed system specification. Official Brave and Mozilla repositories are exercised in an isolated ARM64 preflight before any long native builds. Brave is the default browser and Firefox is retained as an alternative. Moonlight remains pinned and forced through the dedicated media stack, but its stream resolution, refresh rate and HDR request are now derived from the active Wayland output and EDID at launch instead of assuming every screen is 3840×2160 HDR.

The image now includes Btrfs/Ext/exFAT/NTFS/VFAT userspace support and explicit Btrfs, exFAT, NTFS3 and VFAT kernel gates. Its emergency swapfile helper recreates the swapfile with no-copy-on-write and no-compression attributes when the root filesystem is Btrfs. This makes the eventual NVMe-root migration safe without allowing the builder or current test image to touch the installed NVMe.

UK locale, keyboard, timezone and Wi-Fi regulatory defaults are explicit. Security-only unattended upgrades are enabled without automatic reboot. Any Linux-input controller is accepted; Guide+Start toggles the gamepad OSK. Steam is always visible in ES-DE as experimental and bootstraps on demand. ES-DE also exposes Brave, Firefox, network, audio, desktop, restart, reboot and power-off entries.

## Lumera decision

Lumera was considered and rejected for this image generation. It is a promising controller-oriented Android TV client, but it is an Android application using the Android SDK, Android TV manifest integration and Media3 ExoPlayer. Its `arm64-v8a` ABI means Android/Bionic ARM64, not native Ubuntu ARM64. Running it here would require an Android container and a compatible RK3588 Android graphics/video codec stack. That would add an unvalidated platform layer on a 4 GB board and would not establish Linux V4L2 Request hardware decoding. Stremio already builds as a native GTK/Wayland ARM64 application and can be linked directly to the image's audited FFmpeg/mpv stack, so it remains the technically safer choice.

## Release gates still pending

A successful host build and offline image QA are necessary but not sufficient. Hardware testing must still prove:

- boot/display stability on the Orange Pi 5 Pro;
- Panthor/PanVK graphics;
- Gamescope + ES-DE controller-first session;
- broad wired/Bluetooth controller support and gamepad OSK;
- onboard Wi-Fi and Bluetooth;
- HDMI/DisplayPort and Bluetooth audio paths;
- EasySMX X20 operation over wired USB, 2.4 GHz receiver and Bluetooth, including axes/buttons and force feedback where the transport exposes it;
- real Stremio H.264, HEVC 8-bit, HEVC Main10/HDR10, VP9 and AV1 V4L2 Request hardware decode, including 4K visible playback and evidence from the Stremio process itself;
- a real Moonlight stream at the display mode detected at launch, using the hardware-accelerated FFmpeg decoder; a 4K display must therefore prove a 4K stream;
- memory/thermal behavior on the 4 GB board.

Until those pass, V3.20 remains a development generation. Steam ARM64 remains experimental and cannot block the stable image. The newly installed NVMe may be enumerated and SMART-checked read-only, but it must not be mounted, partitioned, formatted or used for the OS until the image is finalized. After approval, use Armbian's interactive `armbian-install` to keep boot on SD while moving the root filesystem to Btrfs on NVMe. When eMMC is purchased, move the bootloader/boot environment to eMMC while retaining the NVMe Btrfs root, validate cold boot, and only then remove the SD card.
