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
mandatory_cmds=(es-de gamescope labwc gamepad-osk opencode moonlight-qt duckstation armsx2 ppsspp rmg flycast melonds azahar snes9x-gtk dolphin-emu sameboy mgba-qt nestopia brave-browser firefox node wpctl nmcli cec-ctl nvme armbian-install opi-brave opi-firefox opi-moonlight-display-auto opi-stremio-hwcheck opi-stremio-session-check opi-moonlight-hwcheck opi-moonlight-session-check opi-controller-check opi-audio-check opi-nvme-check opi-validation-report)
for cmd in "${mandatory_cmds[@]}"; do command -v "$cmd" >/dev/null 2>&1 || { echo "Mandatory command missing from target rootfs: $cmd" >&2; exit 1; }; done
if ! test -x /usr/sbin/greetd && ! command -v greetd >/dev/null 2>&1; then echo "greetd binary missing from target rootfs" >&2; exit 1; fi
mandatory_files=(/etc/greetd/config.toml /etc/opi/session-mode /etc/gamepad-osk/config /etc/modules-load.d/opi-gaming.conf /usr/lib/udev/rules.d/80-gamepad-osk.rules /usr/local/bin/opi-gaming-session /usr/local/bin/opi-desktop-session /usr/local/bin/opi-session-dispatch /usr/local/bin/opi-stremio-hwcheck /usr/local/bin/opi-stremio-session-check /usr/local/bin/opi-moonlight-hwcheck /usr/local/bin/opi-moonlight-session-check /usr/local/bin/opi-moonlight-display-auto /usr/local/bin/opi-controller-check /usr/local/bin/opi-audio-check /usr/local/bin/opi-nvme-check /usr/local/bin/opi-validation-report /home/ryan/.emulationstation/custom_systems/es_systems.xml "/home/ryan/.config/Moonlight Game Streaming Project/Moonlight.conf" /home/ryan/ROMs/ports/Brave-Browser.sh /home/ryan/ROMs/ports/Firefox-Browser.sh /home/ryan/ROMs/ports/Steam-Experimental.sh /home/ryan/ROMs/ports/Restart-Gaming-Mode.sh /opt/opi/apps/moonlight/moonlight-qt /opt/stremio/stremio /opt/stremio/server.js /opt/stremio/libopi-stremio-hwdec.so /opt/opi/media/bin/mpv /opt/opi/media/bin/ffmpeg /opt/opi-build-meta/h264-hwprobe.mp4 /opt/opi-build-meta/hevc-hwprobe.mp4 /opt/opi-build-meta/hevc-main10-hwprobe.mp4 /opt/opi-build-meta/h264-4k-hwprobe.mp4 /opt/opi-build-meta/hevc-main10-4k-hdr10-hwprobe.mp4 /opt/opi-build-meta/vp9-4k-hwprobe.webm /opt/opi-build-meta/av1-4k-hwprobe.mkv)
for f in "${mandatory_files[@]}"; do [[ -e "$f" ]] || { echo "Mandatory target file missing: $f" >&2; exit 1; }; done
[[ -e /opt/opi/media/lib/libmpv.so ]] || { echo "Dedicated libmpv linker/runtime path is missing" >&2; exit 1; }
[[ -s /opt/stremio/server.js ]] || { echo "Stremio server.js is empty" >&2; exit 1; }
grep -aFq 'v4l2request-copy' /opt/stremio/stremio || { echo "Stremio binary lacks mandatory v4l2request policy" >&2; exit 1; }
grep -qx 'videodec=1' "/home/ryan/.config/Moonlight Game Streaming Project/Moonlight.conf" || { echo "Moonlight is not forced to hardware decode" >&2; exit 1; }
for key in width height fps; do grep -Eq "^${key}=[1-9][0-9]*$" "/home/ryan/.config/Moonlight Game Streaming Project/Moonlight.conf" || { echo "Moonlight ${key} safe default is invalid" >&2; exit 1; }; done
[[ "$(cat /etc/opi/session-mode)" == gaming ]] || { echo "Default session mode is not gaming" >&2; exit 1; }
grep -Eq '^[[:space:]]*toggle_combo[[:space:]]*=[[:space:]]*guide\+start([[:space:]]*)$' /etc/gamepad-osk/config || { echo "gamepad-osk Guide+Start toggle is not configured" >&2; exit 1; }
[[ "$(grep -Ec '^[[:space:]]*\[gamepad\][[:space:]]*$' /etc/gamepad-osk/config)" -eq 1 ]] || { echo "gamepad-osk config does not contain exactly one [gamepad] section" >&2; exit 1; }
awk 'BEGIN{ok=0} /^\[mouse\]/{mouse=1;next} /^\[/{mouse=0} mouse && /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true[[:space:]]*$/{ok=1} END{exit !ok}' /etc/gamepad-osk/config || { echo "gamepad-osk controller mouse is not enabled" >&2; exit 1; }
LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd /opt/stremio/stremio > /tmp/stremio-ldd.txt
! grep -q 'not found' /tmp/stremio-ldd.txt || { cat /tmp/stremio-ldd.txt >&2; echo "Stremio has unresolved shared libraries" >&2; exit 1; }
grep -Eq 'libmpv\.so[^ ]*[[:space:]]+=>[[:space:]]+/opt/opi/media/' /tmp/stremio-ldd.txt || { cat /tmp/stremio-ldd.txt >&2; echo "Stremio is not resolving libmpv from /opt/opi/media" >&2; exit 1; }
LD_LIBRARY_PATH=/opt/opi/media/lib ldd /opt/opi/apps/moonlight/moonlight-qt > /tmp/moonlight-ldd.txt
! grep -q 'not found' /tmp/moonlight-ldd.txt || { cat /tmp/moonlight-ldd.txt >&2; echo "Moonlight has unresolved shared libraries" >&2; exit 1; }
for lib in libavcodec libavutil libswscale; do grep -Eq "${lib}\\.so[^ ]*[[:space:]]+=>[[:space:]]+/opt/opi/media/lib/" /tmp/moonlight-ldd.txt || { cat /tmp/moonlight-ldd.txt >&2; echo "Moonlight is not resolving project $lib" >&2; exit 1; }; done
custom_elfs=(/usr/local/bin/gamepad-osk /opt/opi/apps/moonlight/moonlight-qt /opt/opi/apps/ppsspp/PPSSPPSDL /opt/stremio/stremio /opt/opi/media/bin/mpv /opt/opi/media/bin/ffmpeg)
for cmd in es-de rmg flycast melonds azahar snes9x-gtk; do custom_elfs+=("$(command -v "$cmd")"); done
for f in "${custom_elfs[@]}"; do if file -Lb "$f" | grep -q '^ELF'; then LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd "$f" > /tmp/opi-ldd.txt 2>&1 || true; if grep -q 'not found' /tmp/opi-ldd.txt; then echo "Unresolved shared library in $f:" >&2; cat /tmp/opi-ldd.txt >&2; exit 1; fi; fi; done
while IFS= read -r -d '' f; do bash -n "$f" || { echo "Shell syntax failure in target script: $f" >&2; exit 1; }; done < <(find /usr/local/bin /usr/local/sbin /usr/local/libexec/opi-emulators /home/ryan/ROMs/ports -maxdepth 2 -type f -print0 2>/dev/null)
for f in /usr/share/keyrings/brave-browser-archive-keyring.gpg /etc/apt/sources.list.d/brave-browser-release.sources /etc/apt/keyrings/packages.mozilla.org.asc /etc/apt/sources.list.d/mozilla.sources /etc/apt/preferences.d/mozilla; do [[ -s "$f" ]] || { echo "Official browser repository file missing: $f" >&2; exit 1; }; done
gpg --batch --show-keys --with-colons /usr/share/keyrings/brave-browser-archive-keyring.gpg 2>/dev/null | grep -Fqi 'fpr:::::::::D16166072CACDF2C9429CBF11BF41E37D039F691:' || { echo "Brave signing-key fingerprint mismatch" >&2; exit 1; }
gpg --batch --show-keys --with-colons /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null | grep -Fqi 'fpr:::::::::35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3:' || { echo "Mozilla signing-key fingerprint mismatch" >&2; exit 1; }
[[ "$(dpkg-query -W -f='${Architecture}' brave-browser)" == arm64 && "$(dpkg-query -W -f='${Architecture}' firefox)" == arm64 ]] || { echo "Browser packages are not ARM64" >&2; exit 1; }
grep -qx 'x-scheme-handler/https=brave-browser.desktop' /home/ryan/.config/mimeapps.list || { echo "Brave is not the default HTTPS browser" >&2; exit 1; }
if dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | grep -Eq '^(retroarch|libretro|lightdm|xfce4)(:|$|-)'; then echo "Forbidden RetroArch/libretro/LightDM/XFCE package is installed" >&2; exit 1; fi
for unit in greetd.service NetworkManager.service bluetooth.service opi-swapfile.service opi-performance.service opi-regdomain.service earlyoom.service apt-daily.timer apt-daily-upgrade.timer; do systemctl is-enabled "$unit" >/dev/null 2>&1 || { echo "Mandatory service is not enabled: $unit" >&2; exit 1; }; done
systemctl --global is-enabled opi-rom-scan.timer >/dev/null 2>&1 || { echo "Global USB ROM scan timer is not enabled" >&2; exit 1; }
for unit in armbian-zram-config.service armbian-ramlog.service systemd-oomd.service systemd-oomd.socket; do if systemctl cat "$unit" >/dev/null 2>&1; then [[ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" == masked ]] || { echo "Conflicting service is not masked: $unit" >&2; exit 1; }; fi; done
for unit in sleep.target suspend.target hibernate.target hybrid-sleep.target; do [[ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" == masked ]] || { echo "Appliance sleep target is not masked: $unit" >&2; exit 1; }; done
test -f /etc/systemd/zram-generator.conf.d/opi.conf
grep -q 'zram-size = ram / 2' /etc/systemd/zram-generator.conf.d/opi.conf
grep -q 'After=local-fs.target armbian-resize-filesystem.service' /etc/systemd/system/opi-swapfile.service
grep -Fq 'btrfs inspect-internal map-swapfile' /usr/local/sbin/opi-ensure-swapfile
grep -q 'After=armbian-hardware-optimize.service' /etc/systemd/system/opi-performance.service
grep -qx 'XKBLAYOUT="gb"' /etc/default/keyboard
grep -qx 'LANG=en_GB.UTF-8' /etc/default/locale
grep -qx 'REGDOMAIN=GB' /etc/default/crda
grep -Fq '"${distro_id}:${distro_codename}-security"' /etc/apt/apt.conf.d/52opi-unattended-upgrades
echo "Build-time target rootfs sanity gate passed"
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
log "Customization complete"
