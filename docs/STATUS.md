# Project status

## Current generation: V3.15

V3.15 is the active build under test.

V3.14 proved the complete native Stremio build repair: the pinned V4L2 Request FFmpeg, dedicated mpv/libmpv and Stremio 1.1.4 all compiled successfully. The run then exposed a GCC 15 incompatibility in Snes9x 1.63's pinned glslang header, which uses `uint32_t` without including `<cstdint>`. V3.15 applies and immediately syntax-checks the minimal header correction before the full Snes9x build.

The V3.15 audit also closes previously untested requirements. Moonlight is now pinned to an immutable commit, linked to the same dedicated V4L2 Request FFmpeg libraries as Stremio, forced to hardware decoding, and configured for 3840×2160 at 60 Hz with HDR enabled. Its binary and a real 4K stream must both produce affirmative hardware-decoder evidence. The image includes H.264, HEVC Main10/HDR10, VP9 and AV1 4K probes, explicit HDMI and Bluetooth audio checks, and an EasySMX X20/XInput controller detector.

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

Until those pass, V3.15 remains a development generation. Steam ARM64 remains experimental and cannot block the stable image. The newly installed NVMe may be enumerated and SMART-checked read-only, but it must not be mounted, partitioned, formatted or used for the OS until the image is finalized. After approval, use Armbian's interactive `armbian-install` to keep boot on SD while moving the root filesystem to NVMe; eMMC migration and SD removal are a later hardware transition.
