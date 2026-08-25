# Orange Pi 5 OS Image Generator

Source repository for the controller-first Orange Pi 5 Pro gaming/media OS image.

This repository is the **working source of truth** for the project. The generated Armbian image, diagnostic bundles, and any standalone one-shot builder are outputs of this repository rather than the primary development source.

The layout deliberately follows the same broad repository philosophy used by projects such as CachyOS' kernel repository: keep build recipes, configuration, source pins and validation in Git; keep generated binaries/images out of Git.

## Current development target

| Item | Current state |
|---|---|
| Profile | `orangepi5pro-gaming` |
| Project generation | V3.20 |
| Board | Orange Pi 5 Pro, RK3588S, 4 GB |
| Base | Armbian build framework |
| Distribution | Ubuntu 26.04 Resolute |
| Kernel | Armbian `edge`, Linux 7.1+ required |
| Session | greetd → Gamescope → ES-DE |
| Desktop fallback | Labwc / Wayland |
| Media | Native Stremio + enforced RK3588 V4L2 Request FFmpeg/libmpv path; H.264/HEVC/Main10/VP9/AV1 4K probes |
| Streaming | Moonlight, forced hardware decode through the same audited media stack; display mode and HDR auto-detected at launch |
| Controllers | Any native Linux-input gamepad; EasySMX X20 is the wired/2.4 GHz/Bluetooth reference device |
| Audio | PipeWire HDMI/DisplayPort plus Bluetooth audio |
| Storage policy | SD boot/current root only during testing; final plan is SD boot + Btrfs NVMe root, later eMMC boot + Btrfs NVMe root |
| Browser | Brave default, Firefox alternative; gamepad mouse/OSK available |
| Status | active development; V3.20 corrects V3.19's final gamepad-mouse validation failure and is ready for a fresh build/test |

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

## Development workflow

Changes should now be made here first:

1. update source pins, package lists, recipes, kernel overrides or rootfs configuration;
2. run `./tools/check.sh`;
3. commit the change with a useful message;
4. build from a fresh workspace;
5. attach the resulting build log to the issue/commit discussion when diagnosing a failure;
6. tag known-good milestones only after the image and hardware validation gates pass.

See `docs/ARCHITECTURE.md`, `docs/BUILDING.md`, `docs/STATUS.md`, `docs/VALIDATION.md` and `docs/V3.20-AUDIT.md`.
