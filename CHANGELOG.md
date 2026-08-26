# Changelog

## V3.25 — current development generation

- Added a persistent, input-keyed Ubuntu Resolute ARM64 build-dependency image. Its key includes the pulled ARM64 base-image content ID, the complete build-package group file and an explicit cache schema. Every cached image is rechecked for ARM64 architecture, `ccache`, and every declared package before use.
- Kept all application sources, build directories, output roots and final artifacts outside the dependency image. Every native artifact is still built sequentially in a new disposable container with an empty artifact directory.
- Added a shared 20 GiB native `ccache` store with content-based compiler identity and per-application namespaces, plus isolated Cargo registry and Go module/build caches. Cache statistics are printed after every native build.
- Enabled Armbian's supported `USE_CCACHE=yes` path so repeated identical kernel/U-Boot compilation can use its persistent Docker cache rather than rebuilding every object after a userspace-only failure.
- Added a persistent URL-keyed download cache. Each hit must match its stored SHA-256; pinned downloads must also match the reviewed expected digest. Invalid entries are discarded and reacquired before entering the fresh workspace.
- Added structured PASS/FAIL elapsed-time records for every stage and the complete build. Failure diagnostics retain the timing table; successful candidates place it beside the image manifest.
- Added executable cache-integrity fixtures, embedded builder-container syntax checks and static guards proving caches stay outside the disposable workspace and never contain merged application artifacts.
- Deliberately retained sequential artifact scheduling, the eight-job native cap, all source/runtime/image gates, fresh Armbian workspaces and the read-only NVMe policy.

V3.25 is the next test generation, not a release declaration. The speed mechanisms require measurement in the next full build, and a completed image plus physical-board evidence remain mandatory.

## V3.24

- Re-audited the complete runtime-package path after the V3.22 PPSSPP/GLEW failure and treated the repeated late `.so` failures as one systemic defect rather than independent missing-package mistakes.
- Changed the clean ARM64 closure stage from a pass/fail consumer into a package-contract producer: after every core and extracted-AppImage ELF resolves, the stage identifies every dpkg-owned system library provider and merges those packages into the final target manifest before Armbian starts.
- Isolated core, DuckStation and ARMSX2 library search paths during early closure, owner derivation and target validation, preventing one bundled application library from accidentally satisfying another application.
- Made the generic runtime collector fail on any resolved `/lib` or `/usr/lib` library without a dpkg owner instead of silently omitting it. It now honors the combined project/AppImage library path and normalizes multiarch package ownership after merged-`/usr` canonicalization.
- Require nonempty, syntactically valid runtime manifests from all ten native artifacts before merging.
- Require every package in the generated runtime contract in the assembled target root and again in the completed raw image, while retaining named checks for critical PPSSPP, Moonlight, gamepad, PanVK, firmware and filesystem runtimes.
- Added executable regression fixtures proving `libGLEW.so.2.2` maps through `/lib` to the `libglew2.2:arm64` owner and proving an unowned system library is rejected.
- Retained V3.23's explicit GLEW declaration, warning cleanup and all earlier hardware, controller, display, audio, browser, storage and native Stremio requirements.

V3.24 is the next test generation, not a release declaration. A completed image and physical-board evidence are still mandatory.

## V3.23

- Audited all 48,650 lines of the V3.22 log. Every source, package, browser, kernel and executable preflight passed; all ten native ARM64 artifacts built; Azahar passed 64/64 tests; Steam and GE-Proton staged; the Armbian kernel and root filesystem built; and customization reached the final target-root ELF gate.
- Fixed the terminal PPSSPP failure: `PPSSPPSDL` requires `libGLEW.so.2.2`, but the target did not contain `libglew2.2`. The clean merged-runtime container happened to receive GLEW through an indirect dependency path, so its successful closure check did not prove the same package selection in Armbian's populated root.
- Made `libglew2.2` an explicit base-image and PPSSPP-artifact runtime dependency. The PPSSPP recipe now proves its manifest and link immediately; the merged ARM64 root, target root and completed raw image independently require the package, library and resolved SONAME.
- Replaced best-effort Steam seed calls through `sudo` with `runuser` and an explicit user environment, eliminating container-hostname lookup warnings without weakening the experimental/non-blocking Steam policy.
- Normalized Stremio's desktop categories to one freedesktop main category, eliminating the duplicate-menu validation hint while retaining Audio/Video, Video and Player classification.
- Retained every V3.22 assurance gate, native Stremio with mandatory real V4L2 Request proof, the controller-first stack, fresh workspaces and the read-only NVMe development policy.

V3.23 is the next test generation, not a release declaration. A completed image and all physical-board gates remain required.

## V3.22

- Performed a whole-image audit after V3.21, including every supplied build log, package manifest, kernel override, artifact recipe, target-root gate, offline-image gate and runtime acceptance helper.
- Made PanVK non-optional by installing `mesa-vulkan-drivers`, requiring the Panfrost Vulkan ICD in the target and raw image, and adding `opi-gpu-check` to reject llvmpipe/lavapipe or a Vulkan device that does not identify the RK3588 Mali/PanVK stack.
- Extended the clean ARM64 runtime-closure stage to DuckStation and ARMSX2. Both extracted AppImages must contain `AppRun`; every executable ELF is checked with bundled-library search paths before Armbian starts, and the target gate repeats the dependency scan.
- Bound DuckStation's rolling ARM64 artifact to reviewed GitHub release ID `368956550` and SHA-256 `e4bedd6285172cc3127fb2634f646d707b5df13e2176579caa39dd9b12ae75a8`; an upstream replacement now fails before extraction.
- Added a one-time WirePlumber policy that selects HDMI/DisplayPort on the first successful user session, then leaves later Bluetooth or HDMI choices untouched. The helper, service and global enablement are target/offline gates.
- Added `RC_CORE` and `MEDIA_CEC_RC`, plus an on-device CEC adapter/input proof, so HDMI-CEC means remote-control input rather than only a `/dev/cec` node.
- Require Armbian's board firmware package and Broadcom Wi-Fi/Bluetooth payload in the target and completed image; runtime validation also proves both payloads before accepting onboard wireless.
- Reworked Moonlight output choice to rank all enabled outputs by their highest EDID-preferred/native mode rather than taking the first/current output.
- Expanded common removable/storage support with F2FS, XFS, ISO9660 and UDF kernel gates plus F2FS/XFS userspace tools, retaining Ext, Btrfs, FAT, exFAT and NTFS support.
- Added static regressions for every new invariant and retained native Stremio with mandatory real V4L2 Request decoding, the controller-first stack, fresh workspaces and the read-only NVMe policy.

V3.22 is the next test generation, not a release declaration. A fresh completed build and all physical-board gates remain required.

## V3.21

- Audited all 48,431 lines of the V3.20 log. Every source/build/browser/kernel preflight passed; all ten native ARM64 artifacts completed; Azahar passed all 64 tests; Steam and GE-Proton staged; artifact collision and package-solvability gates passed; and Armbian reached final target-root validation.
- Fixed the terminal linkage failure where `gamepad-osk` resolved `libSDL3.so.0` but could not resolve `libSDL3_ttf.so.0`. The isolated build had `libsdl3-ttf-dev` and its runtime dependency, but the generated target package set did not retain `libsdl3-ttf0`.
- Added `libsdl3-0` and `libsdl3-ttf0` to the base runtime manifest and explicitly to the gamepad artifact runtime manifest.
- Added a pre-Armbian ARM64 merged-runtime closure stage. It installs the complete generated target package set into a clean Resolute container, overlays the built artifacts, runs `ldconfig`, scans critical custom ELF files with `ldd`, and requires resolved SDL3 plus SDL3_ttf links for `gamepad-osk`.
- Added package, target-root linkage and completed-image file/package assertions for both SDL3 runtimes, plus static regression checks for the new early gate.
- Retained native Stremio and mandatory real V4L2 Request proof, controller-first ES-DE/Gamescope/Labwc, standalone emulators, display-aware Moonlight, official Brave/Firefox, fresh workspaces and the read-only NVMe testing policy.

V3.21 is the next test generation and is not a release declaration. A successful fresh build plus real Orange Pi hardware validation are still required.

## V3.20

- Audited all 48,386 lines of the V3.19 log. The official Brave/Firefox correction passed, all ten native ARM64 builds completed, Azahar passed all 64 tests, Armbian built the kernel/root filesystem, and the target installed V3.18's two missing Moonlight runtime packages before reaching the final rootfs gate.
- Fixed the terminal false-negative `gamepad-osk` gate. The pinned upstream configuration already enabled the controller mouse as `enabled = true # ...`; the old validator incorrectly required `true` to be the final non-whitespace token.
- Added an idempotent target-root normalizer that enables controller mouse input if the upstream default changes, adds the `[mouse]` section if it is absent, and prevents the final result from depending on comments in the upstream example.
- Require exactly one `[mouse]` section and accept legal inline comments in both the target-root gate and the completed-image offline QA.
- Added executable regression fixtures for an existing disabled setting, a missing section and the exact inline-comment syntax that stopped V3.19.
- Retained native Stremio with mandatory V4L2 Request hardware-decoding gates, controller-first ES-DE/Gamescope/Labwc, display-aware Moonlight, official Brave/Firefox, fresh workspaces and the read-only NVMe policy during image testing.
- Added a complete maintainer/operator handbook covering requirements, architecture decisions, component provenance, emulation mapping, build/release workflow, runtime operations, physical validation evidence, storage migration/rollback, troubleshooting, security and primary upstream references. Static checks now verify all relative handbook links.

V3.20 is the next test generation and is not a release declaration. A successful fresh build plus real Orange Pi hardware validation are still required.

## V3.19

- Audited the complete 98-line V3.18 log. All host, ARM64 execution, source-resolution, package, Stremio ABI and distro-command preflights passed before the browser gate stopped on Brave key validation; no compilation began and no image was produced.
- Corrected a wrong-key-class assertion: `D16166072CACDF2C9429CBF11BF41E37D039F691` verifies Brave's installer script, while the release APT keyring currently contains primary fingerprints `DBF1A116C220B8C7164F98230686B78420038257`, `47D32A74E9A9E013A4B4926C68D513D36A73CD96` and `B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0`.
- Require an exact, sorted primary-key set in both the isolated early preflight and target root. This remains fail-closed on an unreviewed key rotation while tolerating certified subkeys.
- Added final target-root assertions that the Brave source remains bound to the official release URI and audited keyring path. The subsequent APT metadata verification and native ARM64 package installation remain mandatory.
- Extended repository validation to syntax-check single-quoted shell programs executed inside containers, which outer-script `bash -n` cannot inspect.
- Retained V3.18's explicit Moonlight SDL2_ttf/Qt Quick Controls dependencies and every V3.17 system requirement.

V3.19 is the next test generation and is not a release declaration. A successful fresh build plus real Orange Pi hardware validation are still required.

## V3.18

- Audited all 48,355 lines of the completed V3.16 log. The build compiled Snes9x, native Stremio, PPSSPP, ES-DE, gamepad-osk, Moonlight and the remaining emulators, then completed the Armbian kernel/rootfs build and reached target customization.
- Fixed the terminal target-root linkage failure by explicitly installing Moonlight's omitted `libsdl2-ttf-2.0-0` and `libqt6quickcontrols2-6` runtime packages.
- Added both packages to the base runtime manifest and Moonlight artifact manifest so the early ARM64 package preflight and artifact merge independently retain them.
- Repaired generic ELF runtime-package collection for merged-`/usr` layouts by retrying dpkg ownership lookup with each library's canonical path.
- Added package, resolved-link and offline-file regression gates for `libSDL2_ttf-2.0.so.0` and `libQt6QuickControls2.so.6`.
- Retained all V3.17 system decisions: native Stremio and mandatory hardware decoding, official Brave/Firefox, display-aware Moonlight, any-controller Linux input, UK defaults, Btrfs-safe eventual NVMe root and read-only NVMe policy during image validation.

V3.18 is the next test generation and is not a release declaration. A successful fresh build plus real Orange Pi hardware validation are still required.

## V3.17

- Kept native Stremio after a renewed Stremio-versus-Lumera evaluation. Lumera remains an Android/Bionic Media3 application and would add an Android container plus a second unproven RK3588 codec path; Stremio remains directly auditable against the required Linux V4L2 Request FFmpeg/libmpv stack.
- Replaced Epiphany with official ARM64 Brave and Firefox packages. The builder validates both repositories, signing-key fingerprints, package architecture and installed commands before the long native build sequence; Brave is the default and both browsers have ES-DE entries.
- Replaced Moonlight's fixed 4K60/HDR settings with launch-time Wayland output and EDID detection. Hardware decode remains forced, the selected resolution/refresh/HDR policy is recorded, and post-stream validation requires the exact detected resolution plus affirmative hardware-decoder evidence.
- Added Btrfs, exFAT, NTFS3 and VFAT kernel gates plus the corresponding common filesystem tools. The emergency swapfile service now detects Btrfs and safely creates a no-copy-on-write, uncompressed swapfile after the eventual NVMe migration.
- Recorded the final storage plan without touching the installed NVMe: test on SD, then SD boot with Btrfs NVMe root after final approval, then eMMC boot with the same NVMe root after eMMC installation and cold-boot validation.
- Applied UK locale, keyboard, timezone and Wi-Fi regulatory defaults and enabled security-only unattended upgrades without automatic reboot.
- Generalized controller validation to any native Linux-input gamepad, changed the OSK chord to Guide+Start, and kept the EasySMX X20 as the wired/2.4 GHz/Bluetooth reference acceptance device.
- Made Steam's experimental launcher permanently visible and on-demand, and added ES-DE entries for browsers, network, audio, desktop, gaming-session restart, reboot and power-off.
- Added a persistent `opi-validation-report` command and expanded build-time, target-root and offline-image assertions for every new policy.

V3.17 is the next test generation and is not a release declaration. A successful fresh build plus real Orange Pi hardware validation are still required.

## V3.16

- Fixed the V3.15 Moonlight packaging stop by explicitly creating `/out/rootfs/usr/local/bin` before redirecting the launcher into it.
- Added immediate Moonlight launcher syntax, executable-mode and target-command assertions inside the ARM64 artifact recipe.
- Expanded generated-payload validation from rootfs customization fragments to artifact recipes. Recipe redirects into `/out/rootfs` now fail static checks unless their literal parent directory is explicitly created first.
- Confirmed from the complete V3.15 log that Snes9x, native Stremio, PPSSPP, ES-DE and gamepad-osk completed, and that Moonlight compiled and passed its dedicated V4L2 Request FFmpeg linkage, RUNPATH and hardware-decoder evidence gates before the packaging-only failure.
- Reviewed every V3.15 warning/error signature. Remaining warnings are upstream compiler/deprecation diagnostics or disabled optional test/dependency probes and did not conceal a failed command.
- Retained native Stremio as a hard requirement, Moonlight 4K hardware-decode validation, EasySMX X20 coverage, HDMI plus Bluetooth audio, experimental Steam status, fresh workspaces and the read-only NVMe policy.

V3.16 is the next test generation and is not a release declaration. A successful fresh build plus real Orange Pi hardware validation are still required.

## V3.15

- Fixed the V3.14 Snes9x 1.63 failure under Ubuntu 26.04/GCC 15 by adding the missing `<cstdint>` include to its pinned glslang `SpvBuilder.h`. The recipe validates the exact source layout, applies the patch exactly once, and compiles the affected header before starting the full build.
- Kept native Stremio. V3.14 proved the corrected FFmpeg, mpv/libmpv and Stremio build sequence, while Lumera remains an Android/Media3 application that would require a new Android container, Android graphics stack and codec HAL on this native Ubuntu image.
- Pinned Moonlight v6.1.0 to its resolved Git commit and linked it to the project's dedicated V4L2 Request FFmpeg libraries rather than Ubuntu's generic FFmpeg.
- Forced Moonlight hardware decode, set 3840×2160/60 Hz/HDR defaults, added dedicated RUNPATH/linkage gates, and patched an affirmative hardware-versus-software decoder record into the pinned build. A real 4K stream must pass the runtime evidence check.
- Expanded Stremio's mandatory offline hardware probes to cover H.264 4K, HEVC Main10 4K HDR10, VP9 4K and AV1 4K in addition to the existing codec probes.
- Added explicit Linux 7.1-verified Rockchip HDMI-audio kernel configuration, PipeWire HDMI plus Bluetooth audio validation, and an EasySMX X20/XInput-compatible controller detector. The audit excludes the nonexistent `SND_SOC_ROCKCHIP` parent while retaining the real Rockchip I2S/TDM driver.
- Added `nvme-cli` and a strictly read-only NVMe inventory/SMART helper. Added gates preventing partition/format operations in the image recipe and verified Armbian's installer at `/usr/bin/armbian-install`; no migration is automated.
- Disabled appliance suspend/hibernate paths and validated the masks in both the assembled root filesystem and final offline image.
- Restored and asserted executable modes for the documented `./build.sh` and `./tools/check.sh` entry points.
- Bounded all network Git operations, disabled interactive credential prompts, and added low-speed failure detection so unreachable sources produce a diagnostic error instead of hanging indefinitely.
- Resolved and built PPSSPP, RMG, Flycast, melonDS and Azahar from immutable commits rather than trusting mutable tag checkouts; each completed artifact must match its pre-build source lock.
- Declared Steam ARM64 experimental; it remains best-effort and is not a stable-image release gate.

V3.15 is the next test generation and is not a release declaration. A successful fresh build plus real Orange Pi hardware validation are still required.

## V3.14

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
