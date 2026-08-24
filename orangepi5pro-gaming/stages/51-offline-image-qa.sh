say "Offline inspection of generated image"
docker run --rm -i --privileged --platform linux/amd64 -v "$SOURCE_IMAGE:/image.img:ro" ubuntu:26.04 bash -seu <<'OFFLINE_QA'
  export DEBIAN_FRONTEND=noninteractive; apt-get update >/dev/null; apt-get install -y --no-install-recommends util-linux file python3 >/dev/null
  loop="$(losetup --read-only --find --show -P /image.img)"; trap "umount /mnt/root 2>/dev/null || true; losetup -d \"$loop\" 2>/dev/null || true" EXIT
  rootpart="$(lsblk -lnpo NAME,TYPE,FSTYPE "$loop" | awk '$2=="part" && ($3=="ext4" || $3=="btrfs") {print $1}' | tail -n1)"; [[ -n "$rootpart" ]] || { echo "No root partition found" >&2; exit 1; }
  mkdir -p /mnt/root; mount -o ro "$rootpart" /mnt/root; R=/mnt/root
  required=(/etc/greetd/config.toml /etc/opi/session-mode /etc/modules-load.d/opi-gaming.conf /usr/local/bin/opi-gaming-session /usr/local/bin/opi-desktop-session /usr/local/bin/opi-stremio-hwcheck /usr/local/bin/opi-stremio-session-check /usr/local/bin/gamepad-osk /usr/bin/epiphany /usr/share/applications/org.gnome.Epiphany.desktop /opt/stremio/stremio /opt/stremio/server.js /opt/stremio/libopi-stremio-hwdec.so /usr/bin/node /opt/opi/media/bin/mpv /opt/opi/media/bin/ffmpeg /opt/opi/media/lib/libmpv.so /opt/opi-build-meta/h264-hwprobe.mp4 /opt/opi-build-meta/hevc-hwprobe.mp4 /opt/opi-build-meta/hevc-main10-hwprobe.mp4 /etc/systemd/zram-generator.conf.d/opi.conf /etc/systemd/system/opi-swapfile.service /etc/systemd/system/opi-performance.service)
  for f in "${required[@]}"; do [[ -e "$R$f" ]] || { echo "Missing from final image: $f" >&2; exit 1; }; done
  [[ -s "$R/opt/stremio/server.js" ]] || { echo "Stremio server.js is empty in final image" >&2; exit 1; }
  grep -aFq 'v4l2request-copy' "$R/opt/stremio/stremio" || { echo "Stremio binary lacks mandatory v4l2request policy" >&2; exit 1; }
  [[ "$(cat "$R/etc/opi/session-mode")" == gaming ]] || { echo "Final image not set to Gaming Mode" >&2; exit 1; }
  for arg in cma=512M consoleblank=0 zswap.enabled=0; do grep -Eq "^extraargs=.*${arg}" "$R/boot/armbianEnv.txt" || { echo "Final image is missing ${arg}" >&2; exit 1; }; done
  grep -q '^ryan:' "$R/etc/passwd" || { echo "ryan user missing" >&2; exit 1; }
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
  for sym in DRM_PANTHOR VIDEO_ROCKCHIP_VDEC VIDEO_DEV ZRAM INPUT_UINPUT UHID INPUT_JOYDEV JOYSTICK_XPAD HID_PLAYSTATION HID_SONY HID_NINTENDO HID_STEAM BRCMFMAC BT BT_HIDP BT_HCIUART RFKILL; do require_cfg_any "$sym"; done
  for sym in DRM_ROCKCHIP ROCKCHIP_DW_HDMI_QP DRM_DW_HDMI_QP DRM_DW_HDMI_QP_CEC MEDIA_CEC_SUPPORT MEDIA_SUPPORT MEDIA_SUPPORT_FILTER MEDIA_PLATFORM_SUPPORT MEDIA_PLATFORM_DRIVERS MEDIA_CONTROLLER V4L_MEM2MEM_DRIVERS ZRAM_BACKEND_ZSTD BRCMFMAC_SDIO BT_HCIUART_BCM RFKILL_INPUT INPUT INPUT_EVDEV INPUT_JOYSTICK HID_SUPPORT HID HIDRAW HID_GENERIC USB_HID JOYSTICK_XPAD_FF JOYSTICK_XPAD_LEDS NEW_LEDS LEDS_CLASS LEDS_CLASS_MULTICOLOR PLAYSTATION_FF SONY_FF NINTENDO_FF; do require_cfg_y "$sym"; done
  for sym in zram uinput uhid; do grep -qx "$sym" "$R/etc/modules-load.d/opi-gaming.conf" || { echo "$sym not configured for module loading" >&2; exit 1; }; done
  [[ -f "$R/etc/systemd/user/opi-rom-scan.timer" && -L "$R/etc/systemd/user/timers.target.wants/opi-rom-scan.timer" ]] || { echo "Global USB ROM scan timer missing/not enabled" >&2; exit 1; }
  for unit in greetd.service NetworkManager.service bluetooth.service opi-swapfile.service opi-performance.service earlyoom.service; do find "$R/etc/systemd/system" -type l -name "$unit" -print -quit | grep -q . || { echo "Mandatory service is not enabled in final image: $unit" >&2; exit 1; }; done
  grep -q 'After=local-fs.target armbian-resize-filesystem.service' "$R/etc/systemd/system/opi-swapfile.service" || { echo "Swapfile service is not ordered after Armbian filesystem resize" >&2; exit 1; }
  grep -q 'After=armbian-hardware-optimize.service' "$R/etc/systemd/system/opi-performance.service" || { echo "Performance service does not run after Armbian hardware optimizer" >&2; exit 1; }
  for unit in armbian-zram-config.service armbian-ramlog.service systemd-oomd.service systemd-oomd.socket; do if [[ -e "$R/usr/lib/systemd/system/$unit" || -e "$R/lib/systemd/system/$unit" ]]; then [[ -L "$R/etc/systemd/system/$unit" && "$(readlink "$R/etc/systemd/system/$unit")" == /dev/null ]] || { echo "Conflicting service is not masked in final image: $unit" >&2; exit 1; }; fi; done
  for f in "$R/opt/stremio/stremio" "$R/opt/stremio/libopi-stremio-hwdec.so" "$R/usr/bin/node" "$R/usr/local/bin/gamepad-osk" "$R/opt/opi/apps/ppsspp/PPSSPPSDL"; do desc="$(file -Lb "$f")"; grep -Eqi 'ARM aarch64|aarch64' <<<"$desc" || { echo "Non-AArch64 critical ELF: $f :: $desc" >&2; exit 1; }; done
  [[ ! -e "$R/etc/apt/sources.list.d/mozilla.sources" && ! -e "$R/etc/apt/preferences.d/mozilla" ]] || { echo "Unexpected Mozilla external APT configuration in final image" >&2; exit 1; }
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
