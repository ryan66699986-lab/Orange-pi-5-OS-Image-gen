# Orange Pi 5 Pro Controller Appliance

This repository is a conventional Armbian `userpatches` profile for the Orange Pi 5 Pro 4 GB. Armbian remains responsible for the root filesystem, kernel, bootloader, image assembly, Docker/container handling, caches, output image and logs.

The profile adds only:

- one normal Armbian configuration,
- one supported extension for package selection and native AArch64 application compilation,
- `customize-image.sh`,
- a small runtime files overlay,
- one thin wrapper that pins Armbian and invokes the normal `compile.sh` target.

## Pinned base

- Board: `orangepi5pro`
- Architecture: ARM64/AArch64
- Distribution: Ubuntu 26.04 Resolute
- Armbian branch: `current`
- Armbian commit: `69f93c10d8a40bbd6db609b9c84ad665c5eab842`
- Linux stable version: `6.18.48`
- Linux commit: `5bbb9c9f8f808710e2123f2b30f0d61d7d698f52`
- Root filesystem: ext4
- Output: uncompressed `.img` plus SHA-256
- Initial target: SD card only

The profile does not configure, partition, format, migrate to, or write an NVMe device. It contains no flashing command and no host block-device workflow.

## Appliance session

The normal boot path is:

`greetd` → automatic login → Gamescope → ES-DE 3.4.1

If Gamescope cannot start, the session falls back directly to the configured desktop session. A Desktop entry is also visible in ES-DE.

The image disables suspend and hibernation, does not install a screen locker, runs PipeWire/WirePlumber, exposes Network/Audio/Bluetooth utilities in ES-DE, and uses `udiskie` for removable-media automounting.

Each configured `~/ROMs/<system>` directory contains a `USB` link to `/media/ryan`, so ROMs on mounted USB storage are visible to the same ES-DE system definitions after a rescan.

## Controller behaviour

- No controller model whitelist.
- EasySMX X20 is only the reference controller.
- Guide+A toggles the native controller OSK.
- Home+Start exits the currently launched game and returns to ES-DE.
- Controller pointer navigation is available for normal desktop applications.
- `uinput` and `uhid` are loaded by the image; the pinned Armbian `current` kernel configuration itself is not modified by this profile.

## Media

Stremio 1.1.4 is built natively for ARM64 from commit `d0329f5cec8e904548a938d04c941dfee74a0ad4`.

Its private media stack is:

- Kwiboo FFmpeg `v4l2-request-n8.1`, commit `b57fbbe50c9b2656fad86a1a7eeabfd2b2a50935`
- mpv 0.41.0, commit `41f6a645068483470267271e1d09966ca3b9f413`

Stremio requests `v4l2request-copy`. `glib-compile-schemas` runs after the Stremio GSettings schema is installed.

H.264, HEVC and HEVC Main10 hardware decoding are runtime requirements. AV1 support is included where the kernel/media stack supports it. VP9 hardware decoding is not advertised or required.

Moonlight is built natively from commit `f786e94c7b2f943e24e65d7d74deb539b827fc84`. It uses its normal native decoder/FFmpeg integration rather than being forced through the private Stremio FFmpeg/libmpv tree. Its stderr is retained in `~/.local/state/opi/moonlight.log`.

Gamescope owns the appliance gaming display session. The session selects a connected DRM connector and lets Gamescope use that connector's preferred mode. HDR is enabled only when the selected display EDID advertises HDR metadata and the installed Gamescope exposes HDR support.

## Applications and emulators

Included applications:

- NetworkManager
- PipeWire / WirePlumber
- Bluetooth audio
- Brave (default browser)
- Firefox (Ubuntu's supported Firefox snap integration)
- OpenCode
- Gamescope
- ES-DE 3.4.1
- controller OSK and pointer navigation

Standalone emulator map:

| System | Emulator |
|---|---|
| PlayStation | DuckStation AArch64 |
| PlayStation 2 | ARMSX2 AArch64 |
| PSP | PPSSPP built from source |
| Nintendo 64 | RMG built from source |
| Dreamcast | Flycast built from source |
| GameCube / Wii | Ubuntu AArch64 Dolphin |
| Game Boy / Color | Ubuntu AArch64 SameBoy |
| Game Boy Advance | Ubuntu AArch64 mGBA |
| Nintendo DS | melonDS built from source |
| NES | Ubuntu AArch64 Nestopia |
| SNES | Snes9x built from source |

The remaining exact source pins and download checksums are in `extensions/opi-native/sources.env`. Ubuntu package versions are recorded by the Armbian build log for the specific image build.

## Build

Docker should already work for the current user when building from a non-Ubuntu host.

```bash
cd ~
git clone https://github.com/armbian/build.git armbian-opi5pro
git clone https://github.com/ryan66699986-lab/Orange-pi-5-OS-Image-gen.git \
  armbian-opi5pro/userpatches
cd armbian-opi5pro/userpatches
./build.sh
```

`build.sh` does only two project-specific things: it checks out the pinned Armbian commit in the parent checkout, then executes:

```text
compile.sh build opi5pro
```

Armbian keeps its normal source/package/rootfs caches. If a build fails, update the `userpatches` repository and run the same command again; do not delete and reclone the Armbian tree merely to retry.

Optional native compilation parallelism:

```bash
OPI_NATIVE_JOBS=4 ./build.sh
```

Normal outputs are under:

```text
../output/images/
../output/logs/
```

`COMPRESS_OUTPUTIMAGE=sha,img` requests an uncompressed Armbian `.img` and SHA-256 output without xz compression.

## Flashing

Use a graphical imager such as Armbian Imager, Raspberry Pi Imager's custom-image option, or Balena Etcher:

1. Select the generated `.img`.
2. Select the intended SD card.
3. Confirm the removable target carefully.
4. Flash and safely eject it.
5. Boot the Orange Pi 5 Pro from that SD card.

No command-line flashing instructions are part of this project.

## First boot

The image initially creates user `ryan` with temporary password `orangepi`; the appliance forces password replacement before entering the normal ES-DE flow.
