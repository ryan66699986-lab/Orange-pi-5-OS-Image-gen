# Orange Pi 5 Pro Controller Image

This repository is a standard Armbian `userpatches` profile for the Orange Pi 5 Pro 4 GB. It does not contain a second build framework or wrapper. Armbian builds the OS, records the logs, creates the image, and invokes one extension for the native AArch64 applications.

## Target image

- Ubuntu 26.04 Resolute
- Armbian `edge` / Linux 7.1
- ext4 SD-card root for initial hardware validation
- greetd autologin into Gamescope and ES-DE 3.4.1
- direct Labwc/ES-DE recovery if Gamescope fails
- native Stremio 1.1.4 with dedicated V4L2 Request FFmpeg 8.1 and mpv 0.41.0
- native Moonlight and controller on-screen keyboard
- PipeWire HDMI/DisplayPort and Bluetooth audio, selected by the user during hardware setup
- NetworkManager, Brave, Firefox and OpenCode
- native AArch64 standalone emulators for every configured system

## Controller-first behaviour

- Any Linux-input gamepad is accepted; no controller whitelist is used.
- EasySMX X20 is the reference controller.
- Guide+A opens the controller on-screen keyboard.
- Home+Start exits the currently launched game.
- Left stick moves the pointer in desktop/application mode.
- A is primary click, B is secondary click, Y is Enter and X is Escape.
- The D-pad sends arrow keys; the left shoulder sends Tab.
- Desktop, Stremio, Moonlight, Brave, Firefox, OpenCode, reboot and power-off are visible in ES-DE.
- Gamescope uses the connected display's active preferred mode. HDR is enabled only when the display EDID advertises HDR and the installed Gamescope supports it.

## Native emulator map

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
| Nintendo 3DS | Azahar built from source |
| NES | Ubuntu AArch64 Nestopia |
| SNES | Snes9x built from source |

## Build on CachyOS

Docker must already work for the current user. Armbian prepares the remaining
build dependencies inside its container.

```bash
cd ~
git clone https://github.com/armbian/build.git armbian-opi5pro
git clone https://github.com/ryan66699986-lab/Orange-pi-5-OS-Image-gen.git \
  armbian-opi5pro/userpatches
cd armbian-opi5pro
./compile.sh build opi5pro
```

That is the complete image command. Armbian uses Docker automatically on
CachyOS. Keep this checkout after the build: Armbian reuses its own downloaded
sources, packages, rootfs and build artifacts.

If a build fails, fix or update the profile and run the same standard command
again. Do not delete or reclone the Armbian directory:

```bash
cd ~/armbian-opi5pro
git pull --ff-only
git -C userpatches pull --ff-only
./compile.sh build opi5pro
```

Each invocation uses a fresh temporary image root while keeping Armbian's caches.
Its cleanup handlers remove the temporary mounted root after success or failure.

The image is written to:

```text
~/armbian-opi5pro/output/images/
```

Armbian's own logs are written to:

```text
~/armbian-opi5pro/output/logs/
```

Native AArch64 compilation under QEMU can take several hours. Set the build parallelism only when necessary:

```bash
OPI_NATIVE_JOBS=4 ./compile.sh build opi5pro
```

## First boot

The image boots directly into the controller-first password setup. The temporary password is `orangepi`. Press Guide+A for the on-screen keyboard and replace it immediately. ES-DE starts after the password is changed.

Do not migrate to NVMe or Btrfs until the SD-card image boots, the controller workflows work, every emulator launches, and real Stremio playback uses the RK3588 hardware decoder.

The installed dedicated media tools are:

```text
/opt/opi/media/bin/ffmpeg
/opt/opi/media/bin/mpv
```

Stremio and Moonlight are linked to that dedicated media stack rather than the distribution FFmpeg.

After booting on the Orange Pi, the included lightweight validator can check the
installed stack, a user-supplied codec sample, and evidence from real Stremio
playback:

```bash
opi-stremio-validate stack
opi-stremio-validate file /path/to/test-video.mkv
# Play a video in Stremio, then:
opi-stremio-validate playback
```

Audio-output choice, Moonlight display tuning, USB ROM layout and other personal
policy are deliberately left for on-device setup after the base SD image boots.
