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

## Hybrid persistence invariant

Every attempt uses a fresh versioned output workspace under the builder user's home directory. A failed checkout, rootfs, application build or artifact tree is diagnostic-only and is removed before the next attempt. Do not manually resume those outputs.

Generated images and diagnostic bundles are written outside the repository under `~/opi5pro-images`.

The persistent cache root defaults to `~/.cache/opi5pro-builder` and is deliberately outside the repository and workspace. It may contain verified downloads, an input-keyed dependency image, compiler/language caches and the official bare Armbian Git mirror. It never contains a mutable build checkout, userpatch tree, native application output, merged root, target root or image. `OPI5PRO_CACHE_ROOT` may select another absolute dedicated directory; the builder canonicalises it and rejects `/`, the home directory, repository, workspace and output tree as unsafe cache roots.

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
| `18-builder-dependency-cache` | Pull the ARM64 base, resolve an input key, create or verify the dependency-only builder image |
| `20-armbian-kernel` | Update/verify the official bare Armbian mirror, create a fresh detached checkout, inspect edge kernel and stage explicit Kconfig |
| `21-arm64-build-helper` | Prepare reusable isolated ARM64 recipe runner |
| `30-opencode-appimages` | Download OpenCode and extract official ARM64 emulator AppImages |
| `31-native-artifacts` | Build Snes9x, Stremio, PPSSPP, ES-DE, gamepad-osk, Moonlight and remaining native emulators |
| `32-steam-and-merge` | Optionally seed Steam/GE-Proton and merge validated artifacts into one overlay |
| `33-runtime-closure` | Install the complete target package manifest in clean ARM64 Resolute, overlay built artifacts and reject unresolved critical ELF dependencies before Armbian |
| `40-rootfs-assembly` | Generate ordered Armbian rootfs customization and bundled media probes |
| `50-final-audit-build` | Recheck source/artifact hashes and kernel requirements, then build the raw image |
| `51-offline-image-qa` | Mount the completed raw image in a privileged container and inspect the final filesystem |

Snes9x is intentionally first because its pinned legacy dependency chain has been a high-risk GCC/CMake compatibility point. Stremio follows before other long builds because media is a hard requirement.

Native artifacts remain sequential and retain the global eight-job cap. V3.26 does not speculate about parallel scheduling without host utilisation and memory evidence. Every stage emits a machine-readable elapsed-time row. Failed diagnostics contain `stage-timings.tsv`; successful output contains `<image-name>-STAGE-TIMINGS.tsv`.

## Safe cache contract

- The dependency image key includes the pulled Ubuntu ARM64 image ID, `packages/build-groups.txt` hash and cache-schema version. Every hit reruns architecture, command and package-presence validation.
- Native C/C++ compilation uses a shared 20 GiB ccache with content-based compiler verification and a separate namespace for each application.
- Cargo and Go reuse only their external registry/module/compiler caches. Their source and target/output directories are recreated.
- Downloads are keyed by their URL and accompanied by a SHA-256 sidecar. A corrupt hit is discarded. Assets with a reviewed digest, including DuckStation, must also match that digest.
- Armbian runs with `USE_CCACHE=yes`; its build root and target root remain fresh.
- The bare Armbian mirror is origin-checked, remotely updated, connectivity-verified and copied into a new detached checkout. The checkout does not share mutable objects or output state with a failed build.
- Cache reuse never bypasses source locks, artifact architecture checks, ELF owner closure, target-root validation or raw-image QA.

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

V3.26 retains V3.24's complete runtime-package contract and V3.25's verified caches. Snes9x stays first, all ten native artifacts are rebuilt, and DuckStation's rolling ARM64 artifact must match its reviewed digest. Only immutable source acquisition is persistent; do not reuse any earlier version's checkout, userpatches, rootfs or artifacts.

The builder does not touch the Orange Pi's installed NVMe. Storage migration is a post-validation, on-device operation and is outside image generation.

## What a successful build does not prove

QEMU cannot prove RK3588 GPU/VDEC behavior. Raw-image inspection cannot prove display modes, Bluetooth radio behavior, audio playback, controller quirks, thermal stability or actual Stremio/Moonlight rendering. A successful build creates a hardware-test candidate only; follow `VALIDATION.md`.
