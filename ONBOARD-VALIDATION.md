# OpenCode on-board acceptance plan

Run this only after the generated SD-card image has been flashed and the Orange Pi 5 Pro has booted. This is the project validation phase; the host build is not evidence of hardware success.

OpenCode should collect the actual command output and relevant logs into a dated report. Do not modify, repartition, format or migrate the NVMe device while validating.

## 1. Identify the exact running image

Record:

```bash
uname -a
cat /etc/armbian-release
dpkg-query -W 'linux-image-*' 2>/dev/null
```

Confirm the running kernel is the image's pinned 6.18.48-based `current` build and record the exact Armbian kernel package string.

## 2. Boot, DRM and GPU

Record:

```bash
ls -l /dev/dri
dmesg | grep -Ei 'panthor|panvk|gpu|drm|rockchip' | tail -n 200
vulkaninfo --summary
```

Confirm a render node exists and that the active Mesa/Vulkan path is hardware accelerated. Record any Panthor/PanVK errors rather than assuming success.

Check the active display and EDID:

```bash
for s in /sys/class/drm/card*-*/status; do echo "== $s =="; cat "$s"; done
for e in /sys/class/drm/card*-*/edid; do
  test -s "$e" || continue
  echo "== $e =="
  edid-decode "$e"
done
```

Confirm Gamescope starts at the display's normal preferred mode. If HDR metadata exists, confirm HDR is enabled only on that display; if no HDR metadata exists, confirm HDR is not forced.

## 3. Rockchip media devices

Record:

```bash
v4l2-ctl --list-devices
ls -l /dev/video* /dev/media* 2>/dev/null
dmesg | grep -Ei 'vdec|hantro|vsi|video|v4l2|rockchip' | tail -n 300
```

Do not infer codec support only from device-node existence.

## 4. Controller, OSK and pointer

Record the reference controller's Linux input nodes with:

```bash
cat /proc/bus/input/devices
lsmod | grep -Ei 'uinput|uhid|xpad|hid_(nintendo|playstation|sony|steam)|hidp'
```

Then physically verify:

- a normal Linux gamepad is accepted without model-specific configuration,
- Guide+A opens and closes the OSK,
- controller pointer navigation works in Labwc,
- OSK/pointer interaction works in NetworkManager, Stremio, Brave, Firefox and OpenCode,
- Home+Start exits an actually running emulator and returns to ES-DE.

Home+Start means the controller's Guide/Home button (`BTN_MODE`) plus Start; Select+Start is not an accepted substitute.

## 5. Networking and removable storage

Record:

```bash
nmcli general
nmcli device
bluetoothctl show
lsblk -o NAME,MODEL,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

Confirm Wi-Fi and Bluetooth operate on the Orange Pi 5 Pro.

Insert a normal USB storage device and confirm `udiskie` mounts it below `/media/ryan`. Put test ROMs on USB storage, rescan ES-DE and prove that the same system definitions can discover both USB ROMs and ROMs under `~/ROMs`.

The NVMe device may be listed for visibility only. Do not mount-write, partition, format or migrate it as part of this validation.

## 6. Audio

Record:

```bash
wpctl status
aplay -l
```

Use the supplied audio UI to test HDMI/DisplayPort audio and Bluetooth audio. Do not add an automatic output-switching policy just to make the test pass.

## 7. Stremio native stack

Record build/runtime identity:

```bash
file /opt/stremio/stremio
/opt/opi/media/bin/ffmpeg -hide_banner -version
/opt/opi/media/bin/ffmpeg -hide_banner -hwaccels
/opt/opi/media/bin/mpv --version
/opt/opi/media/bin/mpv --no-config --hwdec=help
ldd /opt/stremio/stremio
```

Confirm the binary is AArch64 and the private FFmpeg/mpv tree is the one shipped by the image.

Before playback:

```bash
rm -f ~/.local/state/opi/stremio.log
```

Perform real Stremio playback tests using known samples for:

- H.264
- HEVC 8-bit
- HEVC Main10

For each sample, preserve:

```bash
cp ~/.local/state/opi/stremio.log \
  ~/.local/state/opi/stremio-<codec>-$(date +%Y%m%d-%H%M%S).log
```

Inspect the logs and mpv/video-decoder messages. A passing result must show that actual playback selected `v4l2request-copy`/V4L2 Request hardware decoding. Any software-decoder selection or fallback is a failure for H.264, HEVC or HEVC Main10.

Also test AV1 and report the actual result without upgrading an experimental Hantro/VSI path into a claimed requirement.

Do not require or advertise RK3588 VP9 hardware decoding. If VP9 software-decodes, report that separately rather than marking the image failed for the prohibited/non-required VP9 claim.

Human playback checks must also cover visible picture, colour, frame pacing, audio/video sync and stability.

## 8. Moonlight

Start Moonlight from ES-DE, establish a real stream and preserve:

```bash
cp ~/.local/state/opi/moonlight.log \
  ~/.local/state/opi/moonlight-$(date +%Y%m%d-%H%M%S).log
```

Record whether Moonlight says its selected decoder is hardware accelerated or software. Confirm the image did not force Moonlight through `/opt/opi/media` merely to share Stremio's private FFmpeg.

Test controller input in the stream and check the connected display mode/HDR behaviour.

## 9. Emulators

For every configured system, launch at least one legal test/homebrew image or user-provided title and record:

- executable used,
- whether it starts,
- controller input,
- audio,
- graphics,
- Home+Start return to ES-DE.

Confirm the executable paths correspond to the standalone emulator map in `README.md`.

## 10. Final result

The report must separate:

- **PASS** — observed on the physical Orange Pi,
- **FAIL** — observed failure with logs,
- **NOT TESTED** — no evidence collected,
- **EXPERIMENTAL** — specifically for support such as AV1 when applicable.

Do not convert a successful Armbian image build into a claim that the appliance has passed hardware acceptance.
