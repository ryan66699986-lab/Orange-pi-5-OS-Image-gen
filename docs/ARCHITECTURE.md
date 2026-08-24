# Architecture

The repository has one current image profile: `orangepi5pro-gaming`.

The profile is intentionally separated into reviewable inputs:

- `sources.env`: pinned upstream versions/commits;
- `packages/`: Ubuntu runtime and source-build dependency manifests;
- `kernel/edge-overrides.conf`: human-reviewable kernel requirements;
- `recipes/`: native ARM64 artifact build recipes;
- `rootfs/customize.d/`: ordered Armbian rootfs customization fragments;
- `stages/`: host-side image orchestration.

`build.sh` sources the ordered stages in one shell so the current V3.10 behavior can remain stateful without hiding the build in one giant generated script.

The resulting image defaults to greetd → Gamescope → ES-DE. Labwc is the lightweight Wayland desktop fallback. RetroArch/libretro, XFCE and LightDM are intentionally absent.

The media path is treated as architecture, not an optional enhancement: Stremio must use the RK3588 V4L2 Request hardware decode path for both H.264 and HEVC.
