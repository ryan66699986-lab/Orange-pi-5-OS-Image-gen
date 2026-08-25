# Emulation subsystem

ES-DE owns presentation and library navigation. Each console launches a standalone emulator through a small wrapper under `/usr/local/libexec/opi-emulators`; there is no RetroArch/libretro layer.

## System matrix

| System | Emulator | Acquisition | ROM directory | Recognized extensions |
|---|---|---|---|---|
| PlayStation | DuckStation | Official ARM64 AppImage, extracted | `~/ROMs/ps1` | `cue`, `chd`, `iso`, `pbp` |
| PlayStation 2 | ARMSX2 | Official Linux ARM64 4K-page AppImage, extracted | `~/ROMs/ps2` | `iso`, `chd` |
| PSP | PPSSPP | Native pinned source build | `~/ROMs/psp` | `iso`, `cso`, `chd` |
| Nintendo 64 | RMG | Native pinned source build | `~/ROMs/n64` | `z64`, `n64`, `v64`, `zip` |
| Dreamcast | Flycast | Native pinned source build | `~/ROMs/dreamcast` | `chd`, `cdi`, `gdi` |
| GameCube | Dolphin | Ubuntu ARM64 package | `~/ROMs/gc` | `iso`, `rvz`, `gcz` |
| Wii | Dolphin | Ubuntu ARM64 package | `~/ROMs/wii` | `iso`, `rvz`, `wbfs` |
| Game Boy | SameBoy | Ubuntu ARM64 package | `~/ROMs/gb` | `gb`, `zip` |
| Game Boy Color | SameBoy | Ubuntu ARM64 package | `~/ROMs/gbc` | `gbc`, `zip` |
| Game Boy Advance | mGBA | Ubuntu ARM64 package | `~/ROMs/gba` | `gba`, `zip` |
| Nintendo DS | melonDS | Native pinned source build | `~/ROMs/nds` | `nds`, `zip` |
| Nintendo 3DS | Azahar | Native pinned source build | `~/ROMs/n3ds` | `3ds`, `cci`, `cxi` |
| NES | Nestopia | Ubuntu ARM64 package | `~/ROMs/nes` | `nes`, `zip` |
| SNES | Snes9x | Native pinned source build | `~/ROMs/snes` | `sfc`, `smc`, `zip` |
| Ports/apps | Executable shell entries | Image-generated/user-supplied | `~/ROMs/ports` | `sh` |

Uppercase variants of the listed extensions are also accepted.

## BIOS and firmware

The image creates matching directories under `~/BIOS/` and includes only a README. It never downloads or bundles copyrighted console firmware. Supply only firmware dumped from hardware you own and configure each emulator through its native settings where necessary.

## USB library convention

The `opi-rom-scan` service looks for this hierarchy on mounted removable media:

```text
ROMs/
├── ps1/
├── ps2/
├── psp/
├── n64/
├── dreamcast/
├── gc/
├── wii/
├── gb/
├── gbc/
├── gba/
├── nds/
├── n3ds/
├── nes/
├── snes/
└── ports/
```

Files are exposed in the local `~/ROMs/<system>` directories as symlinks; ROM data is not copied. Broken symlinks are removed on the next scan. The user timer scans every 30 seconds and both Gaming Mode and Desktop Mode run udiskie for automounting.

## Controller philosophy

- Prefer each emulator's native SDL/Linux-input mappings.
- Do not impose a global vendor-specific mapping that could break other controllers.
- Use the EasySMX X20 as a three-transport regression device.
- Validate every button, stick, trigger and D-pad with `evtest` before diagnosing an emulator mapping.
- Force-feedback is tested where the controller transport and emulator expose it; lack of force-feedback on a transport that does not advertise it is not an image failure.

## Performance policy

The image requests CPU/device `performance` governors and exposes Vulkan-capable emulator builds where available. The desired balance is maximum visual quality while maintaining a stable 1080p60 for demanding systems. Do not treat that as a universal per-title guarantee: PS2, GameCube/Wii and 3DS compatibility and performance vary by game and emulator.

When tuning a title:

1. begin with the emulator's native Vulkan renderer where supported;
2. preserve native/controller UI access;
3. reduce internal resolution or enhancements before changing global system policy;
4. record title-specific overrides in the emulator, not in the image-wide wrapper;
5. confirm the change does not introduce thermal throttling or memory exhaustion.

## Acceptance set

For each row in the matrix, retain at least one legally owned representative title or homebrew test image that exercises:

- ES-DE discovery and launch;
- controller input and exit flow;
- video rendering and aspect ratio;
- audio output;
- save data or save-state creation where supported;
- ten or more minutes of stable play for light systems and a longer stress sample for demanding systems.

The final validation record should name the test content, emulator version/commit, renderer, internal resolution, observed frame rate and any title-specific exception. RetroAchievements should be tested in emulators that safely support it, but it is not allowed to weaken emulator security or the mandatory core gates.

## Legal boundary

This project provides emulator software and directory configuration only. Users are responsible for applicable law, firmware, encryption keys and game content. ROMs, copyrighted BIOS files and credentials must never be committed, attached to build logs or distributed with images.
