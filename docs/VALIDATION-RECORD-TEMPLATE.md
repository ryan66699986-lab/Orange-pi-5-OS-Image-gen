# Image validation record

Copy this file for each candidate. Store completed records with the image evidence, not with copyrighted content or secrets.

## Identity

| Field | Value |
|---|---|
| Date/tester | |
| Repository commit | |
| VERSION | |
| Image filename | |
| Image SHA-256 | |
| Source-lock path/hash | |
| Build-log path/hash | |

## Hardware

| Field | Value |
|---|---|
| Board/RAM | Orange Pi 5 Pro / 4 GB |
| Cooling | Geekworm 515 / fan result: |
| Power supply | |
| Test SD model/capacity | |
| NVMe model/serial/capacity/SMART | |
| Display/AV receiver | |
| Network | |

## Build/offline gates

| Gate | Result/evidence |
|---|---|
| `./tools/check.sh` | |
| Fresh workspace confirmed | |
| Full build completed | |
| Offline raw-image QA completed | |
| Image hash verified | |

## Boot, graphics and display

| Test | Result/evidence |
|---|---|
| Three cold boots | |
| Gamescope → ES-DE, no fallback | |
| Direct Gaming Mode under Labwc | |
| Simulated Gamescope failure → direct fallback | |
| Normal Gamescope exit → Labwc desktop | |
| `systemctl --failed` | |
| Panthor DRM/render node | |
| PanVK/Vulkan summary | |
| Primary display mode/refresh | |
| Secondary display mode/refresh | |
| HDR detection/output | |
| Hotplug/recovery | |

## Controllers

| Controller/transport | Buttons/axes | OSK/mouse | Rumble | Result |
|---|---|---|---|---|
| EasySMX X20 USB | | | | |
| EasySMX X20 2.4 GHz | | | | |
| EasySMX X20 Bluetooth | | | | |
| Other | | | | |

## Stremio

| Test | Result/evidence |
|---|---|
| `opi-stremio-hwcheck` | |
| `opi-stremio-hwcheck --visible` | |
| H.264 actual playback | |
| HEVC 8-bit actual playback | |
| HEVC Main10/HDR actual playback | |
| VP9/AV1 where available | |
| `opi-stremio-session-check` | |
| Picture/colour/frame pacing/audio sync | |

## Moonlight

| Test | Result/evidence |
|---|---|
| Detected output/mode/refresh/HDR | |
| `opi-moonlight-hwcheck` | |
| Real stream resolution/FPS/HDR | |
| `opi-moonlight-session-check` | |
| Controller/audio/reconnect | |

## Audio, wireless and storage

| Test | Result/evidence |
|---|---|
| HDMI/DP default and playback | |
| Bluetooth audio selection/playback | |
| Wi-Fi join/reconnect | |
| Bluetooth reconnect | |
| exFAT/NTFS/FAT/ext removable media | |
| USB ROM discovery | |
| Read-only NVMe check | |

## Emulators

| System | Emulator/version | Test content | Renderer/resolution | Controller/audio/save | Performance/result |
|---|---|---|---|---|---|
| PS1 | DuckStation | | | | |
| PS2 | ARMSX2 | | | | |
| PSP | PPSSPP | | | | |
| N64 | RMG | | | | |
| Dreamcast | Flycast | | | | |
| GameCube | Dolphin | | | | |
| Wii | Dolphin | | | | |
| GB/GBC | SameBoy | | | | |
| GBA | mGBA | | | | |
| DS | melonDS | | | | |
| 3DS | Azahar | | | | |
| NES | Nestopia | | | | |
| SNES | Snes9x | | | | |

## Desktop, browser and maintenance

| Test | Result/evidence |
|---|---|
| Labwc enter/use/return | |
| Brave controller/OSK/audio/video | |
| Firefox controller/OSK/audio/video | |
| Network/audio settings from ES-DE | |
| Kitty/OpenCode | |
| `opi-appliance-health --strict` | |
| `opi-update check` | |
| Held packages reviewed | |
| Controlled update/apply/reboot, if available | |
| Post-update affected validation | |
| Steam visible/isolated experimental result | |

## Stability

| Field | Value |
|---|---|
| Soak duration/workload | |
| Peak temperature | |
| Throttling/kernel faults | |
| Peak RAM/zram/disk swap | |
| earlyoom events | |
| Failed systemd units after soak | |

## Exceptions and decision

| Exception/WARN | Blocking? | Owner/disposition |
|---|---|---|
| | | |

Final decision: **PASS / FAIL / DEVELOPMENT ONLY**

Approved by/date:
