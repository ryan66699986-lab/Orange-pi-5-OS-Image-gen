# Project status

## Current generation: V3.14

V3.14 is the active build under test.

V3.13 proved the corrected FFmpeg/OpenSSL configuration and completed both FFmpeg and mpv, then failed at the final Stremio link because Meson installed libmpv into a Debian multiarch subdirectory that was outside the dedicated media search path. V3.14 forces a stable non-multiarch libdir and verifies pkg-config and linker visibility before Cargo begins.

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

Until those pass, V3.14 remains a development generation. The newly installed NVMe may be checked read-only, but it must not be initialized or used for the OS until the image is finalized.
