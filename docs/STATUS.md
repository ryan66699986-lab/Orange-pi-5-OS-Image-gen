# Project status

## Current generation: V3.13

V3.13 is the active build under test.

V3.12 fixed the Snes9x/CMake 4 compatibility failure. The subsequent full audit found a deterministic FFmpeg/OpenSSL 3 configuration failure that would have appeared late in the run, and found that Stremio's embedded libmpv did not consume the user `mpv.conf`. V3.13 fixes both issues, pins the exact resolved FFmpeg commit during checkout, and moves Stremio and Snes9x to the beginning of native compilation.

## Lumera decision

Lumera was considered and rejected for this image generation. It is a promising controller-oriented Android TV client, but it is an Android application using the Android SDK, Android TV manifest integration and Media3 ExoPlayer. Its `arm64-v8a` ABI means Android/Bionic ARM64, not native Ubuntu ARM64. Running it here would require an Android container and a compatible RK3588 Android graphics/video codec stack. That would add an unvalidated platform layer on a 4 GB board and would not establish Linux V4L2 Request hardware decoding. Stremio already builds as a native GTK/Wayland ARM64 application and can be linked directly to the image's audited FFmpeg/mpv stack, so it remains the technically safer choice.

## Release gates still pending

A successful host build and offline image QA are necessary but not sufficient. Hardware testing must still prove:

- boot/display stability on the Orange Pi 5 Pro;
- Panthor/PanVK graphics;
- Gamescope + ES-DE controller-first session;
- broad wired/Bluetooth controller support and gamepad OSK;
- onboard Wi-Fi and Bluetooth;
- audio paths;
- real Stremio H.264, HEVC 8-bit and HEVC Main10 V4L2 Request hardware decode, including visible playback and evidence from the Stremio process itself;
- memory/thermal behavior on the 4 GB board.

Until those pass, V3.13 remains a development generation. The newly installed NVMe may be checked read-only, but it must not be initialized or used for the OS until the image is finalized.
