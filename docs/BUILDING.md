# Building

## Host

Use an x86_64 Linux host with Docker, binfmt/QEMU support, sudo/privileged loop-device capability and substantial free disk space. Armbian documents roughly 50 GB as a general framework baseline; this profile builds multiple large native applications and should retain significantly more headroom. The current preflight refuses to continue below its enforced free-space threshold.

Run:

```bash
./tools/check.sh
./build.sh
```

The builder prompts for the initial `ryan` password, hashes it immediately, and does not intentionally log the plaintext value.

Characters are not echoed. The prompt is for the Orange Pi account, not GitHub. Both reads use `/dev/tty` so stage-list input cannot be consumed accidentally.

## Fresh workspace invariant

Every attempt uses a fresh versioned workspace under the builder user's home directory. A failed workspace is diagnostic-only and is removed before the next attempt. Do not manually resume a failed Armbian tree.

Generated images and diagnostic bundles are written outside the repository under `~/opi5pro-images`.

## Pipeline

Stages are lexically ordered and sourced by `build.sh` in one shell:

| Stage | Contract |
|---|---|
| `01-cleanup-workspace` | Remove only the versioned disposable workspace and register failure cleanup |
| `10-host-preflight` | Check host commands, disk, Docker and privileged loop support |
| `11-password` | Read/hash the local account password without logging plaintext |
| `12-binfmt` | Prove Linux ARM64 containers execute under binfmt/QEMU |
| `13-source-resolution` | Resolve mandatory tags/branches to commits, validate layouts/assets and create source lock |
| `14-package-preflight` | Solve every runtime/build dependency group on Resolute ARM64 |
| `15-stremio-toolchain` | Prove GTK/libadwaita/WebKitGTK/Rust/OpenSSL requirements |
| `16-executable-preflight` | Resolve distro commands and paths used by launchers/gates |
| `17-browser-preflight` | Validate official Brave/Mozilla keys, repos, ARM64 packages and executables |
| `20-armbian-kernel` | Clone fresh Armbian, create `userpatches`, inspect edge kernel and stage explicit Kconfig |
| `21-arm64-build-helper` | Prepare reusable isolated ARM64 recipe runner |
| `30-opencode-appimages` | Download OpenCode and extract official ARM64 emulator AppImages |
| `31-native-artifacts` | Build Snes9x, Stremio, PPSSPP, ES-DE, gamepad-osk, Moonlight and remaining native emulators |
| `32-steam-and-merge` | Optionally seed Steam/GE-Proton and merge validated artifacts into one overlay |
| `33-runtime-closure` | Install the complete target package manifest in clean ARM64 Resolute, overlay built artifacts and reject unresolved critical ELF dependencies before Armbian |
| `40-rootfs-assembly` | Generate ordered Armbian rootfs customization and bundled media probes |
| `50-final-audit-build` | Recheck source/artifact hashes and kernel requirements, then build the raw image |
| `51-offline-image-qa` | Mount the completed raw image in a privileged container and inspect the final filesystem |

Snes9x is intentionally first because its pinned legacy dependency chain has been a high-risk GCC/CMake compatibility point. Stremio follows before other long builds because media is a hard requirement.

## Reproducibility and manifests

- `sources.env` contains requested human-readable pins.
- `versions.lock.json` records resolved commits and the builder/profile target.
- Native build stages verify their final checkout still equals the lock.
- Artifact and downloaded payload SHA-256 values are added to the manifest.
- The output image is named from `VERSION`, board, release and branch.
- A pin gives repeatability for source content, but Ubuntu/Armbian archive state and external toolchains can still change. Keep the manifest, image hash and build log with every candidate.

## Output and failure handling

On success, expect the raw `.img`, SHA-256 companion and build metadata under `~/opi5pro-images`. Do not flash an image unless the terminal success report and offline QA are present.

On failure, use the newest `failed-v<version>-<timestamp>` diagnostic directory. The disposable workspace is deleted so the next run cannot accidentally resume it. Diagnose the earliest real failure as described in `TROUBLESHOOTING.md`.

V3.24 retains Snes9x first among native artifacts so the GCC 15/glslang compatibility gate is exercised before the long Stremio and emulator build sequence. It validates generated launchers from artifact recipes and requires their destination directories before redirection. The official Brave and Firefox ARM64 repositories are installed in an isolated preflight before native compilation starts. Brave's exact release-APT primary-key set is validated separately from its installer-script signing key. Moonlight's SDL2_ttf and Qt Quick Controls, gamepad-osk's SDL3/SDL3_ttf, PPSSPP's GLEW 2.2, and Mesa's PanVK runtime are explicit early package-preflight inputs. Every native build must emit a valid runtime manifest. The merged-runtime closure stage then scans core and extracted-AppImage ELF files, derives the dpkg owner of every resolved system library and merges those owners into the final package contract before Armbian starts. DuckStation's rolling ARM64 artifact must match its reviewed digest. The gamepad configuration explicitly enables controller-mouse support and is tested against upstream-style inline comments. Do not reuse any earlier version's Armbian workspace or artifacts.

The builder does not touch the Orange Pi's installed NVMe. Storage migration is a post-validation, on-device operation and is outside image generation.

## What a successful build does not prove

QEMU cannot prove RK3588 GPU/VDEC behavior. Raw-image inspection cannot prove display modes, Bluetooth radio behavior, audio playback, controller quirks, thermal stability or actual Stremio/Moonlight rendering. A successful build creates a hardware-test candidate only; follow `VALIDATION.md`.
