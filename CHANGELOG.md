# Changelog

## V3.14 — current development generation

- Fixed the V3.13 Stremio link failure by forcing mpv/Meson to install `libmpv.so` and `mpv.pc` under `/opt/opi/media/lib` rather than Debian's automatically selected `/opt/opi/media/lib/aarch64-linux-gnu` directory.
- Added a pre-Cargo assertion that the mpv pkg-config libdir, linker symlink and `-L` search path all point to the dedicated media prefix.
- Exported the verified libmpv directory through `LIBRARY_PATH` for Rust's final native link.
- Added target-root and offline-image gates for `/opt/opi/media/lib/libmpv.so`.
- Confirmed from the V3.13 log that exact FFmpeg/mpv source checkout, the OpenSSL 3 configure correction, FFmpeg compilation, V4L2 Request enablement and mpv compilation all succeeded before the link-path failure.

V3.14 is the next test generation and is not a release declaration. Full image and hardware validation are still pending.

## V3.13

- Evaluated Lumera as a possible Stremio replacement. Lumera is an Android TV application built for Android/Bionic and Media3 ExoPlayer; its ARM64 APK is not a native ARM64 Linux build. Adopting it would require an Android container plus an RK3588 Android codec/HAL stack, creating a new unproven graphics, input, memory and hardware-decoding dependency chain. Native Stremio remains the lower-risk fit for the Ubuntu/Wayland image.
- Fixed a deterministic late FFmpeg failure on Ubuntu 26.04/OpenSSL 3 by adding `--enable-version3` alongside `--enable-gpl --enable-openssl`.
- Replaced the moving-ref FFmpeg, mpv and Stremio clones with direct fetches and detached checkouts of the commits resolved into `versions.lock.json`.
- Patched the pinned Stremio libmpv initializer before compilation so `hwdec=v4l2request-copy` and `hwdec-codecs=all` are properties of the actual Stremio player, rather than relying on a user `mpv.conf` that embedded libmpv does not load by default. The existing preload guard remains as defense in depth.
- Added build-time binary inspection for the Stremio V4L2 Request policy and non-empty `server.js` checks in the recipe, target-root gate and final offline image QA.
- Added `RUST_LOG=warn,vd=debug` to the Stremio launcher and `opi-stremio-session-check` so real playback in the Stremio process must leave evidence of `v4l2request-copy` use.
- Expanded the RK3588 hardware probe set to H.264, HEVC 8-bit and HEVC Main10. `opi-stremio-hwcheck --visible` can exercise the real GPU display path in addition to the headless decoder gate.
- Moved Stremio and Snes9x to the start of native artifact compilation so the two highest-risk builds fail early.
- Started and supervised USB automount in the default Gamescope/ES-DE child, not only the Labwc fallback.
- Removed suppressed CMake install failures from the native ES-DE, RMG, Flycast, melonDS, Azahar and Snes9x recipes; incomplete resource installation now stops the responsible artifact immediately.
- Added syntax validation for the embedded offline-image QA program, main-branch CI, and regression checks covering the new media guarantees.
- Restored the executable bit on `tools/check.sh`, allowing the documented `./tools/check.sh` command and CI job to run directly.
- Added manifest entries for the exact commits produced by every native Git build and SHA-256 hashes for every downloaded payload, including mutable or optional release assets.
- Removed the stale V3.10 label from target customization logs.

V3.13 is the next test generation and is not a release declaration. Full image and hardware validation are still pending.

## V3.12

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
