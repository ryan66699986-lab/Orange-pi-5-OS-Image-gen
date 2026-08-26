# Orange Pi 5 Pro Gaming OS — V3.27

V3.27 is a conventional Armbian image recipe for the Orange Pi 5 Pro 4 GB. The image is built by the standard Armbian framework, with one `userpatches` configuration and a small native-application build helper. Every image attempt starts from a fresh, pinned Armbian checkout.

## Release gates

Two requirements are non-negotiable:

1. Stremio must actually use RK3588 V4L2 Request hardware decoding.
2. Every configured emulator must be a native AArch64 application; no x86 translation layer is used.

Image construction checks that the native Stremio shell, custom FFmpeg, libmpv, forced `v4l2request-copy` policy, codec probes, emulator executables and ES-DE mappings are present. Construction alone cannot prove access to the Orange Pi's decoder hardware. After first boot, V3.27 is accepted only when this passes on the board:

```bash
opi-validate
```

That command decodes bundled H.264, HEVC Main10, H.264 4K, HEVC Main10 4K, VP9 4K and AV1 4K probes through `v4l2request-copy`, then requires evidence from a real Stremio playback session. A built image is a candidate; it is not a successful release until the hardware gate passes.

## Image contents

- Ubuntu 26.04 Resolute
- Armbian `edge` / Linux 7.1
- greetd → Gamescope → ES-DE 3.4.1, with direct Labwc recovery
- native Stremio 1.1.4 linked to a dedicated V4L2 Request FFmpeg 8.1 branch and mpv 0.41.0
- native Moonlight and controller on-screen keyboard builds
- PipeWire HDMI/DisplayPort and Bluetooth audio
- NetworkManager, Brave, Firefox and OpenCode
- SD-card ext4 root for hardware validation; Btrfs/NVMe migration is deferred until the SD image passes

| Systems | Native emulator |
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
| Nintendo 3DS | Azahar built from source |
| NES | Ubuntu AArch64 Nestopia |
| SNES | Snes9x built from source |

## Build

Use a Linux host with Docker, Git, curl, rsync, OpenSSL, at least 8 GB RAM and about 50 GB free disk space. ARM64 Docker execution must work; on x86_64 this normally means binfmt/QEMU is installed.

On a Debian or Ubuntu x86_64 build host, install that support once with:

```bash
sudo apt install qemu-user-static binfmt-support
```

```bash
git clone https://github.com/ryan66699986-lab/Orange-pi-5-OS-Image-gen.git
cd Orange-pi-5-OS-Image-gen
./build.sh
```

The script asks once for the initial `ryan` password and immediately converts it to a SHA-512 password hash. It then:

1. downloads checksum-pinned AArch64 application artifacts;
2. compiles the source-pinned native applications in Ubuntu 26.04 ARM64 containers;
3. creates a fresh checkout of the pinned Armbian build commit;
4. adds the native rootfs through `userpatches/overlay`;
5. invokes the normal `./compile.sh build opi5pro` flow.

Nothing from a failed Armbian workspace is resumed. Logs are copied out and the workspace is deleted on both success and failure.

The uncompressed image, checksum and logs are written to:

```text
~/opi5pro-images/v3.27/
```

Useful overrides:

```bash
OPI_BUILD_PARENT=/fast/disk \
OPI_OUTPUT_DIR=/wanted/output \
OPI_NATIVE_JOBS=4 \
./build.sh
```

The default native-build parallelism is two jobs for 8 GB hosts. Increase it only when the host has enough memory.

## First boot test

1. Boot the SD image and confirm ES-DE appears.
2. Open Stremio from Ports and play a known video long enough to populate its playback log.
3. Open a terminal or virtual console and run `opi-validate`.
4. Do not promote the image or migrate it to NVMe unless every check reports `PASS`.

The Orange Pi 5 Pro is a community-supported Armbian board. Armbian exposes the edge kernel for it, but hardware behavior still has to be established on the target board rather than inferred from a successful host build.
