# Design decisions and rationale

This is a compact architecture-decision record. Changes that reverse these decisions must update this file, the requirement/validation documents and the enforcing checks in the same pull request.

## Armbian build framework and Ubuntu Resolute

**Decision:** generate an Armbian image for `orangepi5pro`, `edge`, Ubuntu 26.04 Resolute, ARM64.

**Why:** Armbian supplies the board integration, boot chain, rootfs/image tooling and `armbian-install` migration workflow while allowing reviewable `userpatches` customization. Ubuntu provides the broad ARM64 userspace package base needed by the native emulator, Wayland and Rust/GTK media stacks.

**Trade-off:** Orange Pi 5 Pro edge is not currently an Armbian `KERNEL_TEST_TARGET`. Newer edge kernels are necessary for the desired mainline Rockchip graphics/media path, but make physical boot/display testing mandatory.

## Edge/mainline kernel rather than a vendor multimedia stack

**Decision:** require Linux 7.1+ edge with Rockchip VDEC, Panthor, DRM, HDMI audio/CEC, controller and filesystem symbols explicitly gated.

**Why:** the system is designed around native Wayland/PanVK and the Linux stateless V4L2 Request API. Keeping requirements in `kernel/edge-overrides.conf` makes the kernel contract auditable and avoids coupling the image to opaque vendor userspace libraries.

**Rejected:** relying on Rockchip MPP/closed vendor images as the primary path. That would be a different graphics/media architecture and would not prove the chosen V4L2 Request path.

## Gamescope + ES-DE as Gaming Mode

**Decision:** greetd initially starts Gamescope with ES-DE as the child application.

**Why:** Gamescope provides an appliance-style game session and ES-DE supplies controller-native browsing, metadata and launcher integration. Keeping ES-DE as the launcher allows media, system actions and experimental applications to appear alongside games without making Steam the shell.

**Rejected:** a traditional desktop session as the default. It increases memory use and makes controller-only navigation secondary.

## Labwc rather than XFCE as Desktop Mode

**Decision:** use Labwc, Waybar, Fuzzel, PCManFM-Qt and small standalone services for the fallback desktop.

**Why:** Labwc is a lightweight native Wayland stacking compositor and fits the 4 GB board. It supplies a familiar desktop for troubleshooting and software installation without carrying a complete desktop environment into Gaming Mode.

**Rejected:** XFCE/LightDM. The older prototype used that direction, but it adds an X11-oriented display-manager/desktop stack, more memory pressure and a second competing login/session policy.

## Native standalone emulators rather than RetroArch

**Decision:** map each required console to a standalone native ARM64 emulator.

**Why:** each upstream can be pinned, built and validated independently; native graphical settings and Vulkan paths remain available; failure ownership is clearer; and ES-DE already abstracts launch commands.

**Rejected:** RetroArch/libretro. A core-based aggregation layer would add another configuration/runtime boundary and conflict with the user's preference for standalone native builds.

## Native Stremio rather than Lumera

**Decision:** build Stremio's native Linux GTK4/libadwaita/WebKitGTK/libmpv shell and keep it as a hard release gate.

**Why:** Stremio can be compiled directly against the dedicated Linux FFmpeg/mpv media prefix and its actual embedded libmpv initialization can be patched and inspected. This makes `v4l2request-copy` observable in the real application process.

**Rejected:** Lumera. Its ARM64 build is an Android/Bionic Media3 application, not a native GNU/Linux/Wayland client. It would require an Android container, graphics integration and a separate RK3588 Android codec/HAL path on a 4 GB machine. That adds an unproven platform layer without proving the required Linux hardware-decoding architecture.

## Dedicated FFmpeg/mpv prefix

**Decision:** compile the pinned Kwiboo V4L2 Request FFmpeg branch and pinned mpv under `/opt/opi/media`; link Stremio and Moonlight to that prefix and require RUNPATH/`ldd` evidence.

**Why:** Ubuntu's generic FFmpeg cannot be assumed to contain or select the exact RK3588 stateless decoder path. A dedicated prefix prevents silent linkage to distro libraries and lets the build fail closed if the intended stack is missing.

**Trade-off:** duplicated multimedia libraries increase image size and maintenance burden. The gain is deterministic linkage and a testable hardware-decoding contract.

## Copy-back hardware decoding

**Decision:** select `v4l2request-copy` rather than accepting `auto` or software fallback.

**Why:** the release criterion is hardware decoding. An automatic fallback can make playback appear functional while consuming impractical CPU/memory or producing blank output. Copy-back is selected deliberately because it is explicit and auditable across the current display stack; zero-copy can be revisited only with real-device proof.

## Display-aware Moonlight

**Decision:** detect the active Wayland output, current/preferred mode and EDID HDR metadata at launch; force hardware decode.

**Why:** the image must work across televisions and monitors rather than hard-code 4K60/HDR. Recording the selected mode makes the subsequent session validation objective.

**Rejected:** fixed 3840×2160/60/HDR. It would fail on non-4K or non-HDR displays and violate maximum display compatibility.

## Native Linux input and gamepad OSK

**Decision:** accept any device tagged `ID_INPUT_JOYSTICK=1`, enable kernel HID/uinput/UHID coverage, and run `gamepad-osk` in both sessions with Guide+Start and controller mouse enabled.

**Why:** controller support must not be tied to one VID/PID. The OSK and mouse mapping fill the usability gap in browsers and desktop utilities while native mappings remain primary inside games/emulators.

**Trade-off:** controller quirks still require per-device hardware testing. EasySMX X20 is the reference, not an allowlist.

## Brave plus Firefox

**Decision:** install official ARM64 Brave and Mozilla Firefox packages, make Brave the default, and retain Firefox as an alternative.

**Why:** both have maintained ARM64 packages and modern Wayland-capable engines. Two engines provide a recovery path for site or DRM/UI incompatibility. Repository keys and architectures are validated before long native compilation.

## PipeWire/WirePlumber audio

**Decision:** use PipeWire with WirePlumber, ALSA compatibility, PulseAudio compatibility and BlueZ SPA support.

**Why:** one graph/policy stack can expose HDMI/DisplayPort and Bluetooth sinks, permit runtime user selection, and serve native Wayland applications.

## Maximum performance with explicit 4 GB safety

**Decision:** request performance governors, reserve 512 MB CMA, use half-RAM zstd zram, create a low-priority disk swap fallback and run earlyoom.

**Why:** sustained emulation and 4K media are latency-sensitive, but native builds/applications can exceed 4 GB. zram absorbs transient pressure; disk swap is a last resort; earlyoom preserves the session instead of allowing an unrecoverable system-wide stall.

**Trade-off:** higher idle power and heat. The Geekworm fan and thermal soak testing are therefore release requirements.

## Staged storage migration

**Decision:** validate entirely on SD, then keep boot on SD and migrate root to Btrfs NVMe, then later move boot to eMMC while retaining NVMe root.

**Why:** SD provides a recoverable test boundary; NVMe supplies final OS performance and capacity; eMMC later removes the SD dependency. Separating boot and root reduces the number of variables changed at each stage.

**Rejected:** building or automatically migrating directly onto NVMe. It is destructive, makes rollback harder and would expose user storage before the image is proven.

## Security-only automatic updates

**Decision:** enable security unattended upgrades, disable automatic reboot, and disable the SSH server by default.

**Why:** an appliance needs security maintenance without unexpected restarts during play or media use. Local controller/desktop operation is primary, and remote login was not a project requirement.

## Steam remains experimental

**Decision:** keep Steam visible and bootstrap it on demand, but never make it a stable release gate.

**Why:** Valve's ARM64 client and AArch64 Proton ecosystem remain moving/experimental targets. Hiding it would reduce useful testing; treating it as supported would misstate the image's guarantees.
