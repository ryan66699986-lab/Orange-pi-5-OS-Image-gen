# Project status

## Current generation: V3.12

V3.12 is the active build under test.

V3.11 fixed the `gamepad-osk` CGO compiler omission and progressed through PPSSPP, ES-DE, gamepad-osk, Moonlight, RMG, Flycast, melonDS and Azahar. It then failed while configuring Snes9x 1.63 because Ubuntu 26.04 supplies CMake 4.2 and Snes9x's pinned bundled SPIRV-Cross still declares compatibility older than CMake 3.5. V3.12 supplies the policy-version compatibility floor requested by CMake and makes the source-lock builder identity derive from `VERSION`.

## Release gates still pending

A successful host build and offline image QA are necessary but not sufficient. Hardware testing must still prove:

- boot/display stability on the Orange Pi 5 Pro;
- Panthor/PanVK graphics;
- Gamescope + ES-DE controller-first session;
- broad wired/Bluetooth controller support and gamepad OSK;
- onboard Wi-Fi and Bluetooth;
- audio paths;
- real Stremio H.264 and HEVC V4L2 Request hardware decode;
- memory/thermal behavior on the 4 GB board.

Until those pass, V3.12 remains a development generation. The newly installed NVMe may be checked read-only, but it must not be initialized or used for the OS until the image is finalized.
