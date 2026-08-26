say "Offline inspection of generated image"
docker run --rm -i --privileged --platform linux/amd64 -v "$SOURCE_IMAGE:/image.img:ro" ubuntu:26.04 bash -seu <<'OFFLINE_QA'
  export DEBIAN_FRONTEND=noninteractive; apt-get update >/dev/null; apt-get install -y --no-install-recommends util-linux file binutils python3 >/dev/null
  loop="$(losetup --read-only --find --show -P /image.img)"; trap "umount /mnt/root 2>/dev/null || true; losetup -d \"$loop\" 2>/dev/null || true" EXIT
  rootpart="$(lsblk -lnpo NAME,TYPE,FSTYPE "$loop" | awk '$2=="part" && ($3=="ext4" || $3=="btrfs") {print $1}' | tail -n1)"; [[ -n "$rootpart" ]] || { echo "No root partition found" >&2; exit 1; }
  mkdir -p /mnt/root; mount -o ro "$rootpart" /mnt/root; R=/mnt/root
  required=(/etc/greetd/config.toml /etc/opi/session-mode /etc/modules-load.d/opi-gaming.conf /usr/local/bin/opi-gaming-session /usr/local/bin/opi-desktop-session /usr/local/bin/opi-stremio-hwcheck /usr/local/bin/opi-stremio-session-check /usr/local/bin/opi-moonlight-hwcheck /usr/local/bin/opi-moonlight-session-check /usr/local/bin/opi-moonlight-display-auto /usr/local/bin/opi-controller-check /usr/local/bin/opi-audio-initial-default /usr/local/bin/opi-audio-check /usr/local/bin/opi-gpu-check /usr/local/bin/opi-cec-check /usr/local/bin/opi-nvme-check /usr/local/bin/opi-validation-report /usr/local/bin/opi-brave /usr/local/bin/opi-firefox /usr/local/bin/gamepad-osk /usr/local/bin/moonlight-qt /usr/bin/armbian-install /usr/bin/brave-browser /usr/bin/firefox /usr/share/applications/brave-browser.desktop /usr/share/applications/firefox.desktop /etc/apt/sources.list.d/brave-browser-release.sources /etc/apt/sources.list.d/mozilla.sources /etc/apt/preferences.d/mozilla /etc/systemd/user/opi-audio-initial-default.service /etc/systemd/user/default.target.wants/opi-audio-initial-default.service /usr/share/vulkan/icd.d/panfrost_icd.json /opt/opi/apps/duckstation/AppRun /opt/opi/apps/armsx2/AppRun /home/ryan/ROMs/ports/Steam-Experimental.sh /home/ryan/ROMs/ports/Restart-Gaming-Mode.sh /opt/opi/apps/moonlight/moonlight-qt /opt/opi/apps/ppsspp/PPSSPPSDL /opt/stremio/stremio /opt/stremio/server.js /opt/stremio/libopi-stremio-hwdec.so /usr/bin/node /opt/opi/media/bin/mpv /opt/opi/media/bin/ffmpeg /opt/opi/media/lib/libmpv.so /opt/opi-build-meta/required-packages.txt /usr/lib/aarch64-linux-gnu/libGLEW.so.2.2 /usr/lib/aarch64-linux-gnu/libSDL2_ttf-2.0.so.0 /usr/lib/aarch64-linux-gnu/libSDL3.so.0 /usr/lib/aarch64-linux-gnu/libSDL3_ttf.so.0 /usr/lib/aarch64-linux-gnu/libQt6QuickControls2.so.6 /opt/opi-build-meta/h264-hwprobe.mp4 /opt/opi-build-meta/hevc-hwprobe.mp4 /opt/opi-build-meta/hevc-main10-hwprobe.mp4 /opt/opi-build-meta/h264-4k-hwprobe.mp4 /opt/opi-build-meta/hevc-main10-4k-hdr10-hwprobe.mp4 /opt/opi-build-meta/vp9-4k-hwprobe.webm /opt/opi-build-meta/av1-4k-hwprobe.mkv /etc/systemd/zram-generator.conf.d/opi.conf /etc/systemd/system/opi-swapfile.service /etc/systemd/system/opi-performance.service /etc/systemd/system/opi-regdomain.service)
  for f in "${required[@]}"; do [[ -e "$R$f" ]] || { echo "Missing from final image: $f" >&2; exit 1; }; done
  [[ -s "$R/opt/stremio/server.js" ]] || { echo "Stremio server.js is empty in final image" >&2; exit 1; }
  grep -aFq 'v4l2request-copy' "$R/opt/stremio/stremio" || { echo "Stremio binary lacks mandatory v4l2request policy" >&2; exit 1; }
  grep -qx 'videodec=1' "$R/home/ryan/.config/Moonlight Game Streaming Project/Moonlight.conf" || { echo "Moonlight force-hardware policy missing" >&2; exit 1; }
  for key in width height fps; do grep -Eq "^${key}=[1-9][0-9]*$" "$R/home/ryan/.config/Moonlight Game Streaming Project/Moonlight.conf" || { echo "Moonlight ${key} safe default invalid" >&2; exit 1; }; done
  grep -Eq '^[[:space:]]*toggle_combo[[:space:]]*=[[:space:]]*guide\+start([[:space:]]*)$' "$R/etc/gamepad-osk/config" || { echo "Guide+Start OSK chord missing" >&2; exit 1; }
  [[ "$(grep -Ec '^[[:space:]]*\[mouse\][[:space:]]*$' "$R/etc/gamepad-osk/config")" -eq 1 ]] || { echo "Final config does not contain exactly one [mouse] section" >&2; exit 1; }
  awk 'BEGIN{ok=0} /^[[:space:]]*\[mouse\][[:space:]]*$/{mouse=1;next} /^[[:space:]]*\[/{mouse=0} mouse && /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true([[:space:]]*#.*)?[[:space:]]*$/{ok=1} END{exit !ok}' "$R/etc/gamepad-osk/config" || { echo "Controller mouse is not enabled" >&2; exit 1; }
  [[ "$(cat "$R/etc/opi/session-mode")" == gaming ]] || { echo "Final image not set to Gaming Mode" >&2; exit 1; }
  for arg in cma=512M consoleblank=0 zswap.enabled=0; do grep -Eq "^extraargs=.*${arg}" "$R/boot/armbianEnv.txt" || { echo "Final image is missing ${arg}" >&2; exit 1; }; done
  grep -q '^ryan:' "$R/etc/passwd" || { echo "ryan user missing" >&2; exit 1; }
  for pkg in libsdl3-0 libsdl3-ttf0 libglew2.2 mesa-vulkan-drivers armbian-firmware f2fs-tools xfsprogs; do grep -qx "Package: $pkg" "$R/var/lib/dpkg/status" || { echo "Final image package database lacks $pkg" >&2; exit 1; }; done
  python3 - "$R/opt/opi-build-meta/required-packages.txt" "$R/var/lib/dpkg/status" <<'PY'
import sys
from pathlib import Path

required = {
    line.strip().split(':', 1)[0]
    for line in Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
    if line.strip()
}
installed = set()
for paragraph in Path(sys.argv[2]).read_text(encoding='utf-8').split('\n\n'):
    fields = {}
    for line in paragraph.splitlines():
        if ': ' in line:
            key, value = line.split(': ', 1)
            fields[key] = value
    if fields.get('Status') == 'install ok installed' and fields.get('Package'):
        installed.add(fields['Package'])
missing = sorted(required - installed)
if missing:
    raise SystemExit('Generated runtime packages missing from final image: ' + ', '.join(missing))
print(f'Final image runtime package contract: PASS ({len(required)} packages)')
PY
  find -L "$R/lib/firmware/brcm" -type f -name 'brcmfmac*-sdio.bin*' -print -quit | grep -q . || { echo "Final image lacks Broadcom Wi-Fi firmware" >&2; exit 1; }
  find -L "$R/lib/firmware/brcm" -type f -name '*.hcd' -print -quit | grep -q . || { echo "Final image lacks Broadcom Bluetooth firmware" >&2; exit 1; }
  python3 - "$R" <<'PY'
import json,sys,tomllib,xml.etree.ElementTree as ET
from pathlib import Path
r=Path(sys.argv[1])
with open(r/'home/ryan/.config/waybar/config.jsonc',encoding='utf-8') as f: json.load(f)
with open(r/'etc/greetd/config.toml','rb') as f: tomllib.load(f)
ET.parse(r/'home/ryan/.config/labwc/rc.xml'); ET.parse(r/'home/ryan/.emulationstation/custom_systems/es_systems.xml')
PY
  grep -Eq '^Package: linux-image-.*edge-rockchip64$' "$R/var/lib/dpkg/status" || { echo "Final image does not contain an Armbian edge rockchip64 kernel package" >&2; exit 1; }
  bootcfg="$(find "$R/boot" -maxdepth 1 -type f -name 'config-*' -print | sort -V | tail -n1)"; [[ -n "$bootcfg" ]] || { echo "Final image has no /boot/config-*" >&2; exit 1; }
  require_cfg_any(){ local sym="$1"; grep -Eq "^CONFIG_${sym}=(y|m)$" "$bootcfg" || { echo "Compiled kernel lacks CONFIG_${sym}=y/m" >&2; exit 1; }; }
  require_cfg_y(){ local sym="$1"; grep -qx "CONFIG_${sym}=y" "$bootcfg" || { echo "Compiled kernel lacks CONFIG_${sym}=y" >&2; exit 1; }; }
  for sym in DRM_PANTHOR VIDEO_ROCKCHIP_VDEC VIDEO_DEV ZRAM INPUT_UINPUT UHID INPUT_JOYDEV JOYSTICK_XPAD HID_PLAYSTATION HID_SONY HID_NINTENDO HID_STEAM BRCMFMAC BT BT_HIDP BT_HCIUART RFKILL SOUND SND SND_SOC SND_SOC_HDMI_CODEC SND_SOC_ROCKCHIP_I2S_TDM SND_SIMPLE_CARD; do require_cfg_any "$sym"; done
  for sym in DRM_ROCKCHIP ROCKCHIP_DW_HDMI_QP DRM_DW_HDMI_QP DRM_DW_HDMI_QP_CEC MEDIA_CEC_SUPPORT RC_CORE MEDIA_CEC_RC MEDIA_SUPPORT MEDIA_SUPPORT_FILTER MEDIA_PLATFORM_SUPPORT MEDIA_PLATFORM_DRIVERS MEDIA_CONTROLLER V4L_MEM2MEM_DRIVERS ZRAM_BACKEND_ZSTD BRCMFMAC_SDIO BT_HCIUART_BCM RFKILL_INPUT INPUT INPUT_EVDEV INPUT_JOYSTICK HID_SUPPORT HID HIDRAW HID_GENERIC USB_HID JOYSTICK_XPAD_FF JOYSTICK_XPAD_LEDS NEW_LEDS LEDS_CLASS LEDS_CLASS_MULTICOLOR PLAYSTATION_FF SONY_FF NINTENDO_FF BTRFS_FS VFAT_FS; do require_cfg_y "$sym"; done
  for sym in EXFAT_FS NTFS3_FS F2FS_FS XFS_FS ISO9660_FS UDF_FS; do require_cfg_any "$sym"; done
  for sym in zram uinput uhid; do grep -qx "$sym" "$R/etc/modules-load.d/opi-gaming.conf" || { echo "$sym not configured for module loading" >&2; exit 1; }; done
  [[ -f "$R/etc/systemd/user/opi-rom-scan.timer" && -L "$R/etc/systemd/user/timers.target.wants/opi-rom-scan.timer" ]] || { echo "Global USB ROM scan timer missing/not enabled" >&2; exit 1; }
  [[ -L "$R/etc/systemd/user/default.target.wants/opi-audio-initial-default.service" ]] || { echo "One-time HDMI audio-default service not globally enabled" >&2; exit 1; }
  for unit in greetd.service NetworkManager.service bluetooth.service opi-swapfile.service opi-performance.service opi-regdomain.service earlyoom.service apt-daily.timer apt-daily-upgrade.timer; do find "$R/etc/systemd/system" -type l -name "$unit" -print -quit | grep -q . || { echo "Mandatory service is not enabled in final image: $unit" >&2; exit 1; }; done
  grep -q 'After=local-fs.target armbian-resize-filesystem.service' "$R/etc/systemd/system/opi-swapfile.service" || { echo "Swapfile service is not ordered after Armbian filesystem resize" >&2; exit 1; }
  grep -Fq 'btrfs inspect-internal map-swapfile' "$R/usr/local/sbin/opi-ensure-swapfile" || { echo "Swap helper is not Btrfs-safe" >&2; exit 1; }
  grep -q 'After=armbian-hardware-optimize.service' "$R/etc/systemd/system/opi-performance.service" || { echo "Performance service does not run after Armbian hardware optimizer" >&2; exit 1; }
  for unit in armbian-zram-config.service armbian-ramlog.service systemd-oomd.service systemd-oomd.socket; do if [[ -e "$R/usr/lib/systemd/system/$unit" || -e "$R/lib/systemd/system/$unit" ]]; then [[ -L "$R/etc/systemd/system/$unit" && "$(readlink "$R/etc/systemd/system/$unit")" == /dev/null ]] || { echo "Conflicting service is not masked in final image: $unit" >&2; exit 1; }; fi; done
  for unit in sleep.target suspend.target hibernate.target hybrid-sleep.target; do [[ -L "$R/etc/systemd/system/$unit" && "$(readlink "$R/etc/systemd/system/$unit")" == /dev/null ]] || { echo "Sleep target is not masked in final image: $unit" >&2; exit 1; }; done
  for f in "$R/opt/stremio/stremio" "$R/opt/stremio/libopi-stremio-hwdec.so" "$R/opt/opi/apps/moonlight/moonlight-qt" "$R/usr/bin/node" "$R/usr/local/bin/gamepad-osk" "$R/opt/opi/apps/ppsspp/PPSSPPSDL"; do desc="$(file -Lb "$f")"; grep -Eqi 'ARM aarch64|aarch64' <<<"$desc" || { echo "Non-AArch64 critical ELF: $f :: $desc" >&2; exit 1; }; done
  readelf -d "$R/opt/opi/apps/moonlight/moonlight-qt" | grep -E '(RPATH|RUNPATH).*\/opt\/opi\/media\/lib' >/dev/null || { echo "Moonlight lacks dedicated media RUNPATH" >&2; exit 1; }
  grep -qx 'x-scheme-handler/https=brave-browser.desktop' "$R/home/ryan/.config/mimeapps.list" || { echo "Brave is not the default browser" >&2; exit 1; }
  grep -qx 'XKBLAYOUT="gb"' "$R/etc/default/keyboard" || { echo "UK keyboard layout missing" >&2; exit 1; }
  grep -qx 'LANG=en_GB.UTF-8' "$R/etc/default/locale" || { echo "UK locale missing" >&2; exit 1; }
  grep -qx 'REGDOMAIN=GB' "$R/etc/default/crda" || { echo "GB Wi-Fi domain missing" >&2; exit 1; }
  grep -Fq '"${distro_id}:${distro_codename}-security"' "$R/etc/apt/apt.conf.d/52opi-unattended-upgrades" || { echo "Security-only unattended-upgrade policy missing" >&2; exit 1; }
  grep -Eq '^Package: (retroarch|libretro|lightdm|xfce4)' "$R/var/lib/dpkg/status" && { echo "Forbidden old stack unexpectedly present" >&2; exit 1; } || true
  if find "$R/opt" -type d \( -name .git -o -name node_modules \) -print -quit | grep -q .; then echo "Build tree leaked into final image" >&2; exit 1; fi
  echo "OFFLINE IMAGE QA: PASS"
OFFLINE_QA
cp --sparse=always "$SOURCE_IMAGE" "$IMAGE_OUT"
sha256sum "$IMAGE_OUT" > "${IMAGE_OUT}.sha256"
{ echo "Orange Pi 5 Pro Gaming OS v${PROFILE_VERSION}"; echo "Builder: repository"; echo "Built: $(date --iso-8601=seconds)"; echo "Armbian commit: $ARMBIAN_COMMIT"; echo "Board: orangepi5pro"; echo "Branch: edge"; echo "Release: resolute"; echo "Source image: $(basename "$SOURCE_IMAGE")"; echo; cat "${IMAGE_OUT}.sha256"; } > "${OUT}/${IMAGE_BASENAME}-BUILD-MANIFEST.txt"
[[ -s "$IMAGE_OUT" && -s "${IMAGE_OUT}.sha256" ]] || die "Output image/checksum is empty"
SUCCESS=1
say "DONE"
printf 'Image:\n  %s\n\nChecksum:\n  %s\n\nManifest:\n  %s\n' "$IMAGE_OUT" "${IMAGE_OUT}.sha256" "${OUT}/${IMAGE_BASENAME}-BUILD-MANIFEST.txt"
printf '\nVerify with:\n  sha256sum -c %q\n' "${IMAGE_OUT}.sha256"
printf '\nThe final image is intentionally UNCOMPRESSED.\n'
