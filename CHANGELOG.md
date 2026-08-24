# Changelog

## V3.12 — current development generation

- Fixed the V3.11 Snes9x 1.63 configuration failure under Ubuntu 26.04 Resolute's CMake 4.2 by explicitly setting `CMAKE_POLICY_VERSION_MINIMUM=3.5` for its legacy bundled SPIRV-Cross project.
- Corrected the source-lock manifest's `builder` field to derive from the repository `VERSION` instead of retaining the stale `v3.10-repo` value.
- Added static repository checks for both the Snes9x CMake compatibility flag and dynamically generated builder metadata.
- Confirmed from the V3.11 log that the earlier `gamepad-osk` CGO compiler failure is fixed and that PPSSPP, ES-DE, gamepad-osk, Moonlight, RMG, Flycast, melonDS and Azahar all progressed successfully before Snes9x configuration began.
- Retained the strict fresh-Armbian-workspace rule, native ARM64 emulator policy, controller-first Gamescope/ES-DE/Labwc design, and mandatory Stremio RK3588 hardware-decode validation.

V3.12 is the next test generation and is not a release declaration. Full image and hardware validation are still pending.

## V3.11

- Fixed the V3.10 `gamepad-osk` CGO failure by explicitly installing `build-essential` in both the ARM64 build recipe and the declarative `gamepad` dependency group.
- Added fail-fast compiler checks before `go build`: `command -v gcc`, `gcc --version`, and verification that `CGO_ENABLED=1`.
- Added static repository checks that require the compiler dependency and CGO preflight, preventing this regression from returning.
- Retained the strict fresh-Armbian-workspace rule, native ARM64 emulator policy, controller-first Gamescope/ES-DE/Labwc design, and mandatory Stremio RK3588 hardware-decode validation.

V3.11 is the next test generation and is not a release declaration. Full image and hardware validation are still pending.

## V3.10

- Fixed fresh Armbian checkout handling by explicitly creating and validating `userpatches/` before staging kernel configuration or rootfs customizations.
- Retained Armbian `edge` with a Linux 7.0+ gate and current 7.1 metadata handling.
- Retained the zero-GitHub-REST source validation path introduced in V3.9.
- Retained native ARM64 emulator builds, standalone emulator policy, Labwc/Gamescope session design and final offline image QA.
- Retained native Stremio with mandatory H.264 and HEVC V4L2 Request hardware-decode runtime checks.
- Migrated project development into this source-oriented Git repository.

V3.10 failed while compiling `gamepad-osk` because its isolated ARM64 container did not install a C compiler.
