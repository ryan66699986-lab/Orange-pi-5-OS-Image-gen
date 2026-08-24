# Changelog

## V3.10 — current development generation

- Fixed fresh Armbian checkout handling by explicitly creating and validating `userpatches/` before staging kernel configuration or rootfs customizations.
- Retained Armbian `edge` with a Linux 7.0+ gate and current 7.1 metadata handling.
- Retained the zero-GitHub-REST source validation path introduced in V3.9.
- Retained native ARM64 emulator builds, standalone emulator policy, Labwc/Gamescope session design and final offline image QA.
- Retained native Stremio with mandatory H.264 and HEVC V4L2 Request hardware-decode runtime checks.
- Migrated project development into this source-oriented Git repository.

V3.10 is not a release declaration. Hardware validation is still pending.
