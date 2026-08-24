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

The media path is treated as architecture, not an optional enhancement. Native Stremio is compiled against the dedicated pinned FFmpeg/mpv stack, and its embedded libmpv initializer explicitly selects `v4l2request-copy`. H.264, HEVC 8-bit and HEVC Main10 must pass the standalone RK3588 decoder gate, visible playback must work, and actual Stremio playback must leave hardware-decoding evidence.

Lumera is not included because its ARM64 deliverable targets Android/Bionic and Media3 ExoPlayer rather than native Linux/Wayland and V4L2 Request. An Android container and RK3588 Android codec/HAL integration would be a separate platform project, not a drop-in media client replacement.
