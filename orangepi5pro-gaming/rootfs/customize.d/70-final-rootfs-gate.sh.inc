log "Build-time target rootfs sanity gate"
[[ -z "$(dpkg --audit)" ]] || { echo "dpkg --audit reported package problems" >&2; dpkg --audit >&2; exit 1; }
apt-get check
visudo -cf /etc/sudoers
desktop-file-validate /usr/share/applications/com.stremio.Stremio.desktop
glib-compile-schemas /usr/share/glib-2.0/schemas
python3 - <<'PY'
import json, tomllib, xml.etree.ElementTree as ET
with open('/home/ryan/.config/waybar/config.jsonc', encoding='utf-8') as f: json.load(f)
with open('/etc/greetd/config.toml', 'rb') as f: tomllib.load(f)
ET.parse('/home/ryan/.config/labwc/rc.xml')
ET.parse('/home/ryan/.emulationstation/custom_systems/es_systems.xml')
PY
mandatory_cmds=(es-de gamescope labwc gamepad-osk opencode moonlight-qt duckstation armsx2 ppsspp rmg flycast melonds azahar snes9x-gtk dolphin-emu sameboy mgba-qt nestopia epiphany node wpctl nmcli cec-ctl)
for cmd in "${mandatory_cmds[@]}"; do command -v "$cmd" >/dev/null 2>&1 || { echo "Mandatory command missing from target rootfs: $cmd" >&2; exit 1; }; done
if ! test -x /usr/sbin/greetd && ! command -v greetd >/dev/null 2>&1; then echo "greetd binary missing from target rootfs" >&2; exit 1; fi
mandatory_files=(/etc/greetd/config.toml /etc/opi/session-mode /etc/gamepad-osk/config /etc/modules-load.d/opi-gaming.conf /usr/lib/udev/rules.d/80-gamepad-osk.rules /usr/local/bin/opi-gaming-session /usr/local/bin/opi-desktop-session /usr/local/bin/opi-session-dispatch /usr/local/bin/opi-stremio-hwcheck /home/ryan/.emulationstation/custom_systems/es_systems.xml /opt/stremio/stremio /opt/stremio/server.js /opt/stremio/libopi-stremio-hwdec.so /opt/opi/media/bin/mpv /opt/opi/media/bin/ffmpeg /opt/opi-build-meta/h264-hwprobe.mp4 /opt/opi-build-meta/hevc-hwprobe.mp4)
for f in "${mandatory_files[@]}"; do [[ -e "$f" ]] || { echo "Mandatory target file missing: $f" >&2; exit 1; }; done
[[ "$(cat /etc/opi/session-mode)" == gaming ]] || { echo "Default session mode is not gaming" >&2; exit 1; }
grep -Eq '^[[:space:]]*toggle_combo[[:space:]]*=[[:space:]]*guide\+a([[:space:]]*)$' /etc/gamepad-osk/config || { echo "gamepad-osk Guide+A toggle is not configured" >&2; exit 1; }
[[ "$(grep -Ec '^[[:space:]]*\[gamepad\][[:space:]]*$' /etc/gamepad-osk/config)" -eq 1 ]] || { echo "gamepad-osk config does not contain exactly one [gamepad] section" >&2; exit 1; }
LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd /opt/stremio/stremio > /tmp/stremio-ldd.txt
! grep -q 'not found' /tmp/stremio-ldd.txt || { cat /tmp/stremio-ldd.txt >&2; echo "Stremio has unresolved shared libraries" >&2; exit 1; }
grep -Eq 'libmpv\.so[^ ]*[[:space:]]+=>[[:space:]]+/opt/opi/media/' /tmp/stremio-ldd.txt || { cat /tmp/stremio-ldd.txt >&2; echo "Stremio is not resolving libmpv from /opt/opi/media" >&2; exit 1; }
for f in /usr/local/bin/gamepad-osk /usr/local/bin/moonlight-qt /opt/opi/apps/ppsspp/PPSSPPSDL /opt/stremio/stremio /opt/opi/media/bin/mpv /opt/opi/media/bin/ffmpeg; do if file -Lb "$f" | grep -q '^ELF'; then LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd "$f" > /tmp/opi-ldd.txt 2>&1 || true; if grep -q 'not found' /tmp/opi-ldd.txt; then echo "Unresolved shared library in $f:" >&2; cat /tmp/opi-ldd.txt >&2; exit 1; fi; fi; done
while IFS= read -r -d '' f; do bash -n "$f" || { echo "Shell syntax failure in target script: $f" >&2; exit 1; }; done < <(find /usr/local/bin /usr/local/sbin /usr/local/libexec/opi-emulators /home/ryan/ROMs/ports -maxdepth 2 -type f -print0 2>/dev/null)
[[ ! -e /etc/apt/sources.list.d/mozilla.sources ]] || { echo "Unexpected Mozilla external APT repository present" >&2; exit 1; }
[[ ! -e /etc/apt/preferences.d/mozilla ]] || { echo "Unexpected Mozilla APT pinning present" >&2; exit 1; }
if dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | grep -Eq '^(retroarch|libretro|lightdm|xfce4)(:|$|-)'; then echo "Forbidden RetroArch/libretro/LightDM/XFCE package is installed" >&2; exit 1; fi
for unit in greetd.service NetworkManager.service bluetooth.service opi-swapfile.service opi-performance.service earlyoom.service; do systemctl is-enabled "$unit" >/dev/null 2>&1 || { echo "Mandatory service is not enabled: $unit" >&2; exit 1; }; done
systemctl --global is-enabled opi-rom-scan.timer >/dev/null 2>&1 || { echo "Global USB ROM scan timer is not enabled" >&2; exit 1; }
for unit in armbian-zram-config.service armbian-ramlog.service systemd-oomd.service systemd-oomd.socket; do if systemctl cat "$unit" >/dev/null 2>&1; then [[ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" == masked ]] || { echo "Conflicting service is not masked: $unit" >&2; exit 1; }; fi; done
test -f /etc/systemd/zram-generator.conf.d/opi.conf
grep -q 'zram-size = ram / 2' /etc/systemd/zram-generator.conf.d/opi.conf
grep -q 'After=local-fs.target armbian-resize-filesystem.service' /etc/systemd/system/opi-swapfile.service
grep -q 'After=armbian-hardware-optimize.service' /etc/systemd/system/opi-performance.service
echo "Build-time target rootfs sanity gate passed"
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
log "Customization complete"
