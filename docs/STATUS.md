# Project status

## Current generation: V3.10

V3.10 is the active build under test.

The most recent fixed failure occurred after a successful source/package/kernel preflight: a pristine Armbian checkout did not contain `userpatches/`, so V3.9 failed while copying `linux-rockchip64-edge.config`. V3.10 creates and verifies the directory immediately after cloning Armbian.

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

Until those pass, V3.10 remains a development generation.
