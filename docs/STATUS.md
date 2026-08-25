# Project status

## Current generation: V3.16

V3.16 is the active build under test.

V3.15 proved the Snes9x GCC 15 compatibility repair and completed native builds of Snes9x, Stremio, PPSSPP, ES-DE and gamepad-osk. It also compiled and linked Moonlight 6.1.0 against the dedicated V4L2 Request FFmpeg libraries, passed the binary RUNPATH, dependency and decoder-evidence gates, then stopped while creating its launcher because `/out/rootfs/usr/local/bin` had not been created. V3.16 creates that directory explicitly and validates the installed launcher immediately.

The V3.16 static gate now inspects generated shell/config payloads from both rootfs customization fragments and ARM64 artifact recipes. For literal recipe redirects into `/out/rootfs`, it rejects a launcher unless the parent directory is explicitly initialized first. Moonlight remains pinned, forced through the project media stack, and configured for 3840×2160 at 60 Hz with HDR enabled. The 4K codec, EasySMX X20, HDMI/Bluetooth audio and read-only NVMe policies are unchanged.

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
- a real 3840×2160 Moonlight stream using the hardware-accelerated FFmpeg decoder;
- memory/thermal behavior on the 4 GB board.

Until those pass, V3.16 remains a development generation. Steam ARM64 remains experimental and cannot block the stable image. The newly installed NVMe may be enumerated and SMART-checked read-only, but it must not be mounted, partitioned, formatted or used for the OS until the image is finalized. After approval, use Armbian's interactive `armbian-install` to keep boot on SD while moving the root filesystem to NVMe; eMMC migration and SD removal are a later hardware transition.
