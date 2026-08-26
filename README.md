# Orange Pi 5 OS Image Generator

Source repository for the controller-first Orange Pi 5 Pro gaming/media OS image.

This repository is the **working source of truth** for the project. The generated Armbian image, diagnostic bundles, and any standalone one-shot builder are outputs of this repository rather than the primary development source.

The layout deliberately follows the same broad repository philosophy used by projects such as CachyOS' kernel repository: keep build recipes, configuration, source pins and validation in Git; keep generated binaries/images out of Git.

This is not a generic Armbian remix. It is an appliance-style image with explicit release gates: native ARM64 emulation, a controller-operable interface, real RK3588 hardware video decoding inside Stremio, hardware-decoded Moonlight streaming, and repeatable image construction from auditable source pins. A completed build is a candidate; only physical-board validation can make it known-good.

## Current development target

| Item | Current state |
|---|---|
| Profile | `orangepi5pro-gaming` |
| Project generation | V3.23 |
| Board | Orange Pi 5 Pro, RK3588S, 4 GB |
| Base | Armbian build framework |
| Distribution | Ubuntu 26.04 Resolute |
| Kernel | Armbian `edge`, Linux 7.1+ required |
| Session | greetd → Gamescope → ES-DE |
| Desktop fallback | Labwc / Wayland |
| Media | Native Stremio + enforced RK3588 V4L2 Request FFmpeg/libmpv path; H.264/HEVC/Main10/VP9/AV1 4K probes |
| Streaming | Moonlight, forced hardware decode through the same audited media stack; display mode and HDR auto-detected at launch |
| Controllers | Any native Linux-input gamepad; EasySMX X20 is the wired/2.4 GHz/Bluetooth reference device |
| Audio | PipeWire HDMI/DisplayPort plus Bluetooth; HDMI selected once on first successful session, later user choices preserved |
| Storage policy | SD boot/current root only during testing; final plan is SD boot + Btrfs NVMe root, later eMMC boot + Btrfs NVMe root |
| Browser | Brave default, Firefox alternative; gamepad mouse/OSK available |
| Status | active development; V3.23 explicitly closes PPSSPP's GLEW runtime across every image-validation layer |

## Repository layout

```text
.
├── build.sh
├── orangepi5pro-gaming/
│   ├── profile.env
│   ├── sources.env
│   ├── packages/
│   ├── kernel/
│   ├── recipes/
│   ├── rootfs/customize.d/
│   └── stages/
├── tools/
├── docs/
└── .github/workflows/
```

`orangepi5pro-gaming/` is the self-contained image recipe, analogous to a build-variant directory in a packaging repository. Future profiles can sit beside it without rewriting the repository structure.

## Build

On the x86_64 Linux build host:

```bash
git clone git@github.com:ryan66699986-lab/Orange-pi-5-OS-Image-gen.git
cd Orange-pi-5-OS-Image-gen
./tools/check.sh
./build.sh
```

The build retains the project's strict fresh-workspace rule: every attempt deletes the versioned Armbian workspace and clones a new Armbian tree. Failed workspaces are diagnostic-only and are never resumed.

The builder never writes to the Orange Pi's installed NVMe. During image development the NVMe is limited to read-only inventory and SMART queries. See the storage handbook before any post-validation migration.

## Documentation map

| Document | Purpose |
|---|---|
| [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) | Authoritative goals, non-goals and definition of done |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System boundaries, boot/session topology and media architecture |
| [`docs/DESIGN-DECISIONS.md`](docs/DESIGN-DECISIONS.md) | Choices, rejected alternatives and reasons |
| [`docs/COMPONENTS.md`](docs/COMPONENTS.md) | Component inventory, pins, acquisition and validation strategy |
| [`docs/EMULATION.md`](docs/EMULATION.md) | Console-to-emulator mapping, ROM layout, formats and test scope |
| [`docs/BUILDING.md`](docs/BUILDING.md) | Host requirements, complete pipeline and build outputs |
| [`docs/VALIDATION.md`](docs/VALIDATION.md) | Offline and physical-hardware release gates |
| [`docs/VALIDATION-RECORD-TEMPLATE.md`](docs/VALIDATION-RECORD-TEMPLATE.md) | Reusable evidence sheet for each image candidate |
| [`docs/RELEASE-PROCESS.md`](docs/RELEASE-PROCESS.md) | Versioning, candidate promotion, tagging and rollback |
| [`docs/OPERATIONS.md`](docs/OPERATIONS.md) | Daily use, session switching, helpers, logs and maintenance |
| [`docs/STORAGE.md`](docs/STORAGE.md) | SD/NVMe/eMMC phases, safeguards, migration and rollback |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Failure triage for builds and runtime faults |
| [`docs/REFERENCES.md`](docs/REFERENCES.md) | Curated primary upstream documentation |
| [`docs/STATUS.md`](docs/STATUS.md) | Current generation and outstanding proof |
| [`docs/V3.23-AUDIT.md`](docs/V3.23-AUDIT.md) | Most recent full-log audit and V3.23 closure record |
| [`docs/V3.22-AUDIT.md`](docs/V3.22-AUDIT.md) | Prior whole-image audit and V3.22 assurance expansion |
| [`SECURITY.md`](SECURITY.md) | Security model and responsible reporting |

## Development workflow

Changes should now be made here first:

1. update source pins, package lists, recipes, kernel overrides or rootfs configuration;
2. run `./tools/check.sh`;
3. commit the change with a useful message;
4. build from a fresh workspace;
5. attach the resulting build log to the issue/commit discussion when diagnosing a failure;
6. tag known-good milestones only after the image and hardware validation gates pass.

Start with `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md` and `docs/VALIDATION.md`. Maintainers should also read `CONTRIBUTING.md` before changing the image contract.
