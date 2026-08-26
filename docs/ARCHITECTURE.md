# Architecture

The repository has one current image profile: `orangepi5pro-gaming`. The system is divided into a reproducible build plane and a runtime appliance plane. Generated images and build workspaces are outputs, never sources of truth.

## Build plane

The profile is intentionally separated into reviewable inputs:

- `sources.env`: pinned upstream versions/commits;
- `packages/`: Ubuntu runtime and source-build dependency manifests;
- `kernel/edge-overrides.conf`: human-reviewable kernel requirements;
- `recipes/`: native ARM64 artifact build recipes;
- `rootfs/customize.d/`: ordered Armbian rootfs customization fragments;
- `stages/`: host-side image orchestration.

`build.sh` sources the ordered stages in one shell so the current generation can remain stateful without hiding the build in one giant generated script.

```text
Git profile inputs
  → host/source/package/browser/kernel preflights
  → isolated ARM64 artifact builds
  → merged-overlay ARM64 runtime closure
  → rootfs customization generation
  → fresh Armbian kernel/rootfs/image build
  → target-root gates
  → raw-image offline QA
  → image + checksum + manifest
```

Native artifacts are built in isolated Ubuntu Resolute ARM64 containers through binfmt/QEMU. This catches architecture and package-resolution faults without contaminating the host. After merge, a separate clean ARM64 container installs the complete generated runtime package manifest, overlays the artifacts and checks critical ELF linkage. This prevents a development-only library from surviving the artifact build but disappearing from the target. The Armbian image itself is built in its own fresh workspace. Artifact build success, merged runtime closure, target dependency success and offline image presence are distinct gates.

### Cache plane

The cache plane is outside both the repository and versioned workspace. It has four narrowly defined stores:

| Store | Reusable content | Excluded content |
|---|---|---|
| Builder image | Ubuntu ARM64 build dependencies, keyed by base image/package manifest/schema | Source checkouts and compiled applications |
| Native ccache | Content-verified compiler results, namespaced per application | Linked/install trees and final artifacts |
| Language caches | Cargo registry and Go module/build cache | Stremio/gamepad source and target directories |
| Download cache | URL-keyed bytes plus SHA-256 integrity record | Extracted application trees and merged root |

Cache hits optimize acquisition or compilation; they do not establish correctness. The normal source, architecture, runtime-manifest, merged-closure, target-root and offline-image gates still establish correctness. The Armbian workspace is freshly cloned even while Armbian's supported compiler cache remains external.

## Runtime session topology

```text
greetd initial session
  → opi-session-dispatch
    → gaming: Gamescope → ES-DE + gamepad-osk + udiskie
    → desktop: Labwc → Waybar/Fuzzel/Mako + applets + gamepad-osk + udiskie
```

The resulting image defaults to greetd → Gamescope → ES-DE. Labwc is the lightweight Wayland desktop fallback. RetroArch/libretro, XFCE and LightDM are intentionally absent.

If Gamescope exits, `opi-gaming-session` records its status and executes Desktop Mode. This improves recoverability but does not turn a Gamescope failure into a release pass.

ES-DE's custom systems file maps console collections to normalized wrappers under `/usr/local/libexec/opi-emulators`. The `ports` collection is also the controller-accessible application/system menu.

## Input boundary

Native Linux input is the controller layer. Any controller exposed as a Linux joystick is accepted, Guide+Start toggles the gamepad OSK, and the OSK daemon's mouse mapping makes desktop applications and both browsers usable without requiring a keyboard. Brave is the default browser and Firefox is an installed alternative.

Kernel support includes evdev/joydev, uinput, UHID, generic USB/Bluetooth HID, Xpad and common PlayStation/Nintendo/Steam HID drivers. Userspace acceptance is capability-based (`ID_INPUT_JOYSTICK=1`) rather than based on a controller model. Applications receive native input; the OSK provides keyboard/mouse injection only where needed.

## Graphics and display boundary

The kernel contract requires Rockchip DRM and Panthor, while the package contract explicitly requires Mesa's PanVK ICD. Gamescope, Labwc and applications run Wayland-first with Xwayland as a compatibility path. Display choice is left to DRM/Wayland rather than fixed in the image. Moonlight ranks all enabled outputs by highest EDID-preferred/native mode, parses the selected connector's EDID for HDR static metadata and applies that policy immediately before launch.

No build-time test can prove a real scanout mode, EDID behavior or PanVK stability. Those belong to physical validation.

## Media boundary

The media path is treated as architecture, not an optional enhancement. Native Stremio is compiled against the dedicated pinned FFmpeg/mpv stack, and its embedded libmpv initializer explicitly selects `v4l2request-copy`. H.264, HEVC 8-bit and HEVC Main10 must pass the standalone RK3588 decoder gate, visible playback must work, and actual Stremio playback must leave hardware-decoding evidence.

The same dedicated FFmpeg libraries are linked into Moonlight. Runtime linkage is checked with `ldd`, and the pinned client emits an affirmative record distinguishing hardware from software decoding. The distribution FFmpeg/mpv remains separate and cannot satisfy either application's gate.

The proof chain is intentionally cumulative:

1. kernel exposes the Rockchip stateless decoder and media Request API;
2. dedicated FFmpeg advertises `v4l2request`;
3. dedicated mpv decodes bundled files using `v4l2request-copy`;
4. visible probes render through the graphical path;
5. Stremio's embedded libmpv produces the same evidence during actual playback;
6. Moonlight is linked to the dedicated stack and records hardware decode during a real stream.

Passing an earlier link never substitutes for a later one.

Lumera is not included because its ARM64 deliverable targets Android/Bionic and Media3 ExoPlayer rather than native Linux/Wayland and V4L2 Request. An Android container and RK3588 Android codec/HAL integration would be a separate platform project, not a drop-in media client replacement.

## Audio and device services

PipeWire is the audio server, PipeWire Pulse/ALSA compatibility serves applications, and WirePlumber manages devices/policy. A user oneshot chooses HDMI/DisplayPort only on the first successful session; after recording that choice it never overrides a later Bluetooth or HDMI selection. BlueZ plus the PipeWire BlueZ SPA plugin supplies Bluetooth audio. NetworkManager owns network configuration. UDisks/udiskie automount common removable media in both sessions, and a user timer discovers the documented USB ROM tree.

## Memory and performance

The runtime targets a 4 GB device:

- CPU and available devfreq governors are set to `performance`;
- `cma=512M` reserves contiguous memory needed by the graphics/media pipeline;
- zram uses zstd with a size of half of RAM and swap priority 100;
- a 0.5–2 GB low-priority disk swapfile is created based on free space;
- Btrfs roots receive a NOCOW, uncompressed swapfile;
- earlyoom acts before total memory exhaustion while avoiding the core shell processes where possible;
- suspend/hibernate and console blanking are disabled for appliance stability.

This policy intentionally favors latency/performance over power consumption and requires active cooling/thermal validation.

## Trust and update boundaries

- Repository source pins are resolved to commits and hashes.
- Official browser repositories are key/fingerprint/source-bound and preflighted on ARM64.
- Git network calls have bounded retries/timeouts and cannot prompt for credentials.
- Security-only OS updates are automatic; reboot and broad release upgrades are not.
- Steam and GE-Proton are an optional experimental boundary; their failure must not alter hard production gates.

See `DESIGN-DECISIONS.md` for alternatives and `COMPONENTS.md` for provenance.

## Storage boundary

The tested image boots and runs from SD. The approved final storage topology is boot from SD with a Btrfs root filesystem on NVMe. When eMMC is installed, boot moves to eMMC while the Btrfs root remains on NVMe, allowing SD removal. Migration remains an explicit post-validation `armbian-install` operation; the builder only supplies filesystem support and a Btrfs-safe swapfile service.

The builder cannot see enough user intent to select a destructive target safely, so it contains only read-only NVMe diagnostics and static guards against formatting/migration commands. See `STORAGE.md`.
