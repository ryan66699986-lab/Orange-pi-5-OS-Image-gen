# Architecture

The repository has one current image profile: `orangepi5pro-gaming`.

The profile is intentionally separated into reviewable inputs:

- `sources.env`: pinned upstream versions/commits;
- `packages/`: Ubuntu runtime and source-build dependency manifests;
- `kernel/edge-overrides.conf`: human-reviewable kernel requirements;
- `recipes/`: native ARM64 artifact build recipes;
- `rootfs/customize.d/`: ordered Armbian rootfs customization fragments;
- `stages/`: host-side image orchestration.

`build.sh` sources the ordered stages in one shell so the current generation can remain stateful without hiding the build in one giant generated script.

The resulting image defaults to greetd → Gamescope → ES-DE. Labwc is the lightweight Wayland desktop fallback. RetroArch/libretro, XFCE and LightDM are intentionally absent.

Native Linux input is the controller layer. Any controller exposed as a Linux joystick is accepted, Guide+Start toggles the gamepad OSK, and the OSK daemon's mouse mapping makes desktop applications and both browsers usable without requiring a keyboard. Brave is the default browser and Firefox is an installed alternative.

The media path is treated as architecture, not an optional enhancement. Native Stremio is compiled against the dedicated pinned FFmpeg/mpv stack, and its embedded libmpv initializer explicitly selects `v4l2request-copy`. H.264, HEVC 8-bit and HEVC Main10 must pass the standalone RK3588 decoder gate, visible playback must work, and actual Stremio playback must leave hardware-decoding evidence.

Lumera is not included because its ARM64 deliverable targets Android/Bionic and Media3 ExoPlayer rather than native Linux/Wayland and V4L2 Request. An Android container and RK3588 Android codec/HAL integration would be a separate platform project, not a drop-in media client replacement.

The tested image boots and runs from SD. The approved final storage topology is boot from SD with a Btrfs root filesystem on NVMe. When eMMC is installed, boot moves to eMMC while the Btrfs root remains on NVMe, allowing SD removal. Migration remains an explicit post-validation `armbian-install` operation; the builder only supplies filesystem support and a Btrfs-safe swapfile service.
