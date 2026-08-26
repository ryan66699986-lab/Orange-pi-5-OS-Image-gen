# Primary references

These are upstream sources for the architecture and maintenance decisions. Version-specific behavior remains pinned and tested by this repository; an upstream webpage is supporting context, not a substitute for project gates.

## Board, Armbian and Linux

- [Orange Pi 5 Pro product specification](https://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5-Pro.html)
- [Orange Pi 5 Pro official resources and manuals](https://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-5-Pro.html)
- [Armbian build framework overview](https://docs.armbian.com/build-framework/)
- [Armbian build host preparation](https://docs.armbian.com/build-framework/getting-started/)
- [Armbian build switches](https://docs.armbian.com/build-framework/switches/)
- [Armbian user configurations and `customize-image.sh`](https://docs.armbian.com/build-framework/user-configurations/)
- [Armbian getting started and installer overview](https://docs.armbian.com/getting-started/)
- [Linux V4L2 Request API](https://docs.kernel.org/userspace-api/media/mediactl/request-api.html)
- [Linux stateless video decoder interface](https://docs.kernel.org/userspace-api/media/v4l/dev-stateless-decoder.html)
- [Linux stateless codec controls](https://docs.kernel.org/userspace-api/media/v4l/ext-ctrls-codec-stateless.html)
- [Linux media/CEC remote-controller build options](https://docs.kernel.org/admin-guide/media/building.html)

## Session, interface and input

- [Gamescope upstream](https://github.com/ValveSoftware/gamescope)
- [ES-DE upstream](https://gitlab.com/es-de/emulationstation-de)
- [ES-DE user guide](https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md)
- [greetd upstream](https://github.com/kennylevinsen/greetd)
- [tuigreet upstream](https://github.com/apognu/tuigreet)
- [Labwc upstream](https://github.com/labwc/labwc)
- [Labwc documentation](https://labwc.github.io/)
- [gamepad-osk upstream and configuration](https://github.com/0x90shell/gamepad-osk)

## Graphics, media and streaming

- [Mesa Panfrost/PanVK driver documentation](https://docs.mesa3d.org/drivers/panfrost.html)
- [Stremio native Linux shell](https://github.com/Stremio/stremio-linux-shell)
- [mpv upstream](https://github.com/mpv-player/mpv)
- [Kwiboo FFmpeg fork used for V4L2 Request](https://github.com/Kwiboo/FFmpeg)
- [FFmpeg upstream](https://ffmpeg.org/)
- [Moonlight Qt upstream](https://github.com/moonlight-stream/moonlight-qt)
- [Moonlight setup guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- [Moonlight hardware-decoding troubleshooting](https://github.com/moonlight-stream/moonlight-docs/wiki/Fixing-Hardware-Decoding-Problems)
- [PipeWire documentation](https://pipewire.pages.freedesktop.org/pipewire/)
- [WirePlumber documentation](https://pipewire.pages.freedesktop.org/wireplumber/)
- [WirePlumber Bluetooth configuration](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html)
- [WirePlumber ALSA configuration](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html)

## Storage and memory

- [Btrfs swapfile requirements](https://btrfs.readthedocs.io/en/latest/Swapfile.html)
- [Btrfs mount options](https://btrfs.readthedocs.io/en/latest/ch-mount-options.html)
- [systemd zram generator](https://github.com/systemd/zram-generator)
- [nvme-cli upstream](https://github.com/linux-nvme/nvme-cli)

## Browsers and utilities

- [Official Brave Linux installation](https://brave.com/linux/)
- [Official Mozilla Firefox Linux installation](https://support.mozilla.org/en-US/kb/install-firefox-linux)
- [OpenCode upstream](https://github.com/anomalyco/opencode)

## Emulator upstreams

- [DuckStation](https://github.com/stenzek/duckstation)
- [ARMSX2](https://github.com/ARMSX2/ARMSX2)
- [PPSSPP](https://github.com/hrydgard/ppsspp)
- [RMG](https://github.com/Rosalie241/RMG)
- [Flycast](https://github.com/flyinghead/flycast)
- [Dolphin](https://github.com/dolphin-emu/dolphin)
- [SameBoy](https://github.com/LIJI32/SameBoy)
- [mGBA](https://github.com/mgba-emu/mgba)
- [melonDS](https://github.com/melonDS-emu/melonDS)
- [Azahar](https://github.com/azahar-emu/azahar)
- [Nestopia UE](https://github.com/0ldsk00l/nestopia)
- [Snes9x](https://github.com/snes9xgit/snes9x)

## Supply-chain references

- [`sources.env`](../orangepi5pro-gaming/sources.env) — requested source tags/branches/commits.
- [`13-source-resolution.sh`](../orangepi5pro-gaming/stages/13-source-resolution.sh) — resolution and compatibility assertions.
- [`versions.lock.json`](COMPONENTS.md) — generated per-build immutable commit record (not committed as a static file).
- [`THIRD_PARTY.md`](../THIRD_PARTY.md) — licensing and redistribution boundary.
