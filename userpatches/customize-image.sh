#!/usr/bin/env bash
set -Eeuo pipefail

readonly RELEASE="$1"
readonly BOARD="$3"
readonly ARTIFACTS=/tmp/overlay/opi-artifacts
readonly NATIVE_ROOTFS=/tmp/overlay/native-rootfs
readonly PASSWORD_HASH_FILE=/tmp/overlay/opi-user-password.hash

[[ "${RELEASE}" == resolute ]] || { echo "Unexpected release: ${RELEASE}" >&2; exit 1; }
[[ "${BOARD}" == orangepi5pro ]] || { echo "Unexpected board: ${BOARD}" >&2; exit 1; }
[[ -s "${PASSWORD_HASH_FILE}" ]] || { echo "Missing user password hash" >&2; exit 1; }
[[ -d "${NATIVE_ROOTFS}" ]] || { echo "Missing native ARM64 rootfs" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive

echo "Installing native ARM64 applications"
cp -a "${NATIVE_ROOTFS}/." /

echo "Installing pinned application artifacts"
apt-get install -y --no-install-recommends \
    "${ARTIFACTS}/brave-keyring.deb" \
    "${ARTIFACTS}/brave-browser.deb"

install -Dm755 "${ARTIFACTS}/ES-DE_aarch64.AppImage" /opt/es-de/ES-DE.AppImage
tar -xzf "${ARTIFACTS}/opencode-linux-arm64.tar.gz" -C /tmp
install -Dm755 /tmp/opencode /usr/local/bin/opencode
rm -f /tmp/opencode

cat > /usr/local/bin/es-de <<'EOF'
#!/usr/bin/env bash
exec /opt/es-de/ES-DE.AppImage "$@"
EOF
chmod 0755 /usr/local/bin/es-de

cat > /usr/local/bin/duckstation <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export APPDIR=/opt/opi/apps/duckstation
cd "${APPDIR}"
exec ./AppRun "$@"
EOF
cat > /usr/local/bin/armsx2 <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export APPDIR=/opt/opi/apps/armsx2
cd "${APPDIR}"
exec ./AppRun "$@"
EOF
chmod 0755 /usr/local/bin/duckstation /usr/local/bin/armsx2

normalize_command() {
    local name="$1" candidate target=""
    shift
    [[ -x "/usr/local/bin/${name}" ]] && return 0
    for candidate in "$@"; do
        [[ -x "${candidate}" ]] && { target="${candidate}"; break; }
    done
    [[ -n "${target}" ]] || { echo "Missing native command: ${name}" >&2; exit 1; }
    ln -s "${target}" "/usr/local/bin/${name}"
}
normalize_command rmg /usr/local/bin/RMG
normalize_command melonds /usr/local/bin/melonDS
normalize_command azahar /usr/local/bin/azahar-qt /usr/local/bin/citra-qt
normalize_command snes9x-gtk /usr/local/bin/snes9x
normalize_command dolphin-emu /usr/bin/dolphin-emu /usr/games/dolphin-emu
normalize_command sameboy /usr/bin/sameboy /usr/games/sameboy /usr/bin/sameboy-sdl /usr/games/sameboy-sdl
normalize_command mgba-qt /usr/bin/mgba-qt /usr/games/mgba-qt
normalize_command nestopia /usr/bin/nestopia /usr/games/nestopia

echo "Checking mandatory Stremio media stack"
for required in \
    /opt/stremio/stremio \
    /opt/stremio/server.js \
    /opt/stremio/libopi-stremio-hwdec.so \
    /opt/opi/media/bin/ffmpeg \
    /opt/opi/media/bin/mpv \
    /opt/opi/media/lib/libmpv.so; do
    [[ -e "${required}" ]] || { echo "Missing Stremio hardware-decode artifact: ${required}" >&2; exit 1; }
done
MEDIA_LIBRARY_PATH="/opt/opi/media/lib:/opt/opi/media/lib64"
LD_LIBRARY_PATH="${MEDIA_LIBRARY_PATH}" /opt/opi/media/bin/ffmpeg -hide_banner -hwaccels 2>&1 | grep -qi v4l2request || {
    echo "Custom FFmpeg does not expose v4l2request" >&2; exit 1; }
LD_LIBRARY_PATH="${MEDIA_LIBRARY_PATH}" /opt/opi/media/bin/mpv --no-config --hwdec=help 2>&1 | grep -qi v4l2request || {
    echo "Custom mpv does not expose v4l2request" >&2; exit 1; }
unset MEDIA_LIBRARY_PATH
glib-compile-schemas /usr/share/glib-2.0/schemas

echo "Creating the console user"
if ! id ryan >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash --comment 'Ryan' --user-group ryan
fi
user_groups=()
for group in sudo audio video render input bluetooth netdev games plugdev; do
    getent group "${group}" >/dev/null 2>&1 && user_groups+=("${group}")
done
((${#user_groups[@]})) && usermod -aG "$(IFS=,; echo "${user_groups[*]}")" ryan
printf 'ryan:%s\n' "$(<"${PASSWORD_HASH_FILE}")" | chpasswd --encrypted
passwd --lock root
rm -f /root/.not_logged_in_yet

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
printf 'Europe/London\n' > /etc/timezone
sed -Ei 's/^# (en_GB.UTF-8 UTF-8)$/\1/' /etc/locale.gen
locale-gen en_GB.UTF-8
printf 'LANG=en_GB.UTF-8\n' > /etc/default/locale

install -d -m0755 /etc/gamepad-osk
cp /usr/share/gamepad-osk/config /etc/gamepad-osk/config
sed -Ei 's/^[[:space:]]*toggle_combo[[:space:]]*=.*/toggle_combo = guide+a/' /etc/gamepad-osk/config

install -d -m0755 /etc/opi /etc/greetd /usr/local/libexec/opi /usr/share/wayland-sessions
printf 'gaming\n' > /etc/opi/session-mode

cat > /usr/local/bin/opi-labwc-startup <<'EOF'
#!/usr/bin/env bash
set -u
mkdir -p "${HOME}/.local/state"
swaybg -c '#20242b' >/dev/null 2>&1 &
waybar >/dev/null 2>&1 &
nm-applet --indicator >/dev/null 2>&1 &
blueman-applet >/dev/null 2>&1 &
mako >/dev/null 2>&1 &
udiskie --automount --notify >/dev/null 2>&1 &
gamepad-osk --daemon --config /etc/gamepad-osk/config >/dev/null 2>&1 &
if [[ "${OPI_DIRECT_GAMING:-0}" == 1 ]]; then
    es-de >>"${HOME}/.local/state/es-de.log" 2>&1 &
fi
EOF

cat > /usr/local/bin/opi-desktop-session <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=labwc
export XDG_CURRENT_DESKTOP=labwc
export SDL_AUDIODRIVER=pipewire
export SDL_VIDEODRIVER='wayland,x11'
export QT_QPA_PLATFORM='wayland;xcb'
export MOZ_ENABLE_WAYLAND=1
mkdir -p "${HOME}/.local/state"
exec labwc -s /usr/local/bin/opi-labwc-startup
EOF

cat > /usr/local/bin/opi-direct-gaming-session <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export OPI_DIRECT_GAMING=1
exec /usr/local/bin/opi-desktop-session
EOF

cat > /usr/local/bin/opi-gaming-session <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=opi-gaming
export XDG_CURRENT_DESKTOP=gamescope
export SDL_AUDIODRIVER=pipewire
export SDL_VIDEODRIVER='wayland,x11'
export QT_QPA_PLATFORM='wayland;xcb'
export MOZ_ENABLE_WAYLAND=1
mkdir -p "${HOME}/.local/state"
gamepad-osk --daemon --config /etc/gamepad-osk/config >>"${HOME}/.local/state/gamepad-osk.log" 2>&1 &
osk_pid=$!
trap 'kill "${osk_pid}" 2>/dev/null || true' EXIT INT TERM
if gamescope -f -- es-de 2>>"${HOME}/.local/state/gamescope.log"; then
    kill "${osk_pid}" 2>/dev/null || true
    trap - EXIT INT TERM
    exec /usr/local/bin/opi-desktop-session
fi
kill "${osk_pid}" 2>/dev/null || true
trap - EXIT INT TERM
printf 'Gamescope failed; using direct Labwc/ES-DE recovery.\n' >>"${HOME}/.local/state/gamescope.log"
exec /usr/local/bin/opi-direct-gaming-session
EOF

cat > /usr/local/bin/opi-session-dispatch <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$(cat /etc/opi/session-mode 2>/dev/null || echo gaming)" in
    desktop) exec /usr/local/bin/opi-desktop-session ;;
    direct) exec /usr/local/bin/opi-direct-gaming-session ;;
    *) exec /usr/local/bin/opi-gaming-session ;;
esac
EOF

cat > /usr/local/sbin/opi-set-session <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
    gaming|direct|desktop) printf '%s\n' "$1" > /etc/opi/session-mode ;;
    *) echo 'Usage: opi-set-session gaming|direct|desktop' >&2; exit 2 ;;
esac
rm -f /run/greetd-opi-initial
systemctl --no-block restart greetd
EOF

cat > /usr/local/bin/gaming-mode <<'EOF'
#!/usr/bin/env bash
exec sudo /usr/local/sbin/opi-set-session gaming
EOF
cat > /usr/local/bin/desktop-mode <<'EOF'
#!/usr/bin/env bash
exec sudo /usr/local/sbin/opi-set-session desktop
EOF
cat > /usr/local/bin/direct-gaming-mode <<'EOF'
#!/usr/bin/env bash
exec sudo /usr/local/sbin/opi-set-session direct
EOF

chmod 0755 \
    /usr/local/bin/opi-labwc-startup \
    /usr/local/bin/opi-desktop-session \
    /usr/local/bin/opi-direct-gaming-session \
    /usr/local/bin/opi-gaming-session \
    /usr/local/bin/opi-session-dispatch \
    /usr/local/sbin/opi-set-session \
    /usr/local/bin/gaming-mode \
    /usr/local/bin/desktop-mode \
    /usr/local/bin/direct-gaming-mode

cat > /usr/share/wayland-sessions/opi-gaming.desktop <<'EOF'
[Desktop Entry]
Name=Gaming Mode
Exec=/usr/local/bin/opi-gaming-session
Type=Application
DesktopNames=OPiGaming
EOF
cat > /usr/share/wayland-sessions/opi-labwc.desktop <<'EOF'
[Desktop Entry]
Name=Labwc Desktop
Exec=/usr/local/bin/opi-desktop-session
Type=Application
DesktopNames=Labwc
EOF

install -d -m0755 -o _greetd -g _greetd /var/cache/tuigreet
cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[general]
runfile = "/run/greetd-opi-initial"

[default_session]
command = "tuigreet --time --remember --remember-user-session --cmd /usr/local/bin/opi-desktop-session"
user = "_greetd"

[initial_session]
command = "/usr/local/bin/opi-session-dispatch"
user = "ryan"
EOF

cat > /etc/sudoers.d/opi-session <<'EOF'
ryan ALL=(root) NOPASSWD: /usr/local/sbin/opi-set-session gaming, /usr/local/sbin/opi-set-session direct, /usr/local/sbin/opi-set-session desktop, /usr/bin/systemctl reboot, /usr/bin/systemctl poweroff
EOF
chmod 0440 /etc/sudoers.d/opi-session

install -d -m0755 -o ryan -g ryan /home/ryan/.config/labwc /home/ryan/.emulationstation/custom_systems /home/ryan/ROMs/ports
install -d -m0755 /usr/local/libexec/opi-emulators

cat > /usr/local/libexec/opi-emulators/ps1 <<'EOF'
#!/usr/bin/env bash
exec duckstation -batch "$@"
EOF
cat > /usr/local/libexec/opi-emulators/ps2 <<'EOF'
#!/usr/bin/env bash
exec armsx2 "$@"
EOF
cat > /usr/local/libexec/opi-emulators/psp <<'EOF'
#!/usr/bin/env bash
exec ppsspp "$@"
EOF
cat > /usr/local/libexec/opi-emulators/n64 <<'EOF'
#!/usr/bin/env bash
exec rmg "$@"
EOF
cat > /usr/local/libexec/opi-emulators/dreamcast <<'EOF'
#!/usr/bin/env bash
exec flycast "$@"
EOF
cat > /usr/local/libexec/opi-emulators/gc <<'EOF'
#!/usr/bin/env bash
exec dolphin-emu -b -e "$@"
EOF
cp /usr/local/libexec/opi-emulators/gc /usr/local/libexec/opi-emulators/wii
cat > /usr/local/libexec/opi-emulators/gb <<'EOF'
#!/usr/bin/env bash
exec sameboy "$@"
EOF
cp /usr/local/libexec/opi-emulators/gb /usr/local/libexec/opi-emulators/gbc
cat > /usr/local/libexec/opi-emulators/gba <<'EOF'
#!/usr/bin/env bash
exec mgba-qt "$@"
EOF
cat > /usr/local/libexec/opi-emulators/nds <<'EOF'
#!/usr/bin/env bash
exec melonds "$@"
EOF
cat > /usr/local/libexec/opi-emulators/n3ds <<'EOF'
#!/usr/bin/env bash
exec azahar "$@"
EOF
cat > /usr/local/libexec/opi-emulators/nes <<'EOF'
#!/usr/bin/env bash
exec nestopia "$@"
EOF
cat > /usr/local/libexec/opi-emulators/snes <<'EOF'
#!/usr/bin/env bash
exec snes9x-gtk "$@"
EOF
chmod 0755 /usr/local/libexec/opi-emulators/*

cat > /home/ryan/.config/labwc/rc.xml <<'EOF'
<?xml version="1.0"?>
<labwc_config>
  <core><reuseOutputMode>yes</reuseOutputMode></core>
  <keyboard>
    <keybind key="W-Return"><action name="Execute" command="foot"/></keybind>
    <keybind key="W-g"><action name="Execute" command="gaming-mode"/></keybind>
  </keyboard>
</labwc_config>
EOF

cat > /home/ryan/.emulationstation/custom_systems/es_systems.xml <<'EOF'
<?xml version="1.0"?>
<systemList>
  <system><name>ps1</name><fullname>Sony PlayStation</fullname><path>~/ROMs/ps1</path><extension>.cue .chd .iso .pbp .CUE .CHD .ISO .PBP</extension><command>/usr/local/libexec/opi-emulators/ps1 %ROM%</command><platform>psx</platform><theme>psx</theme></system>
  <system><name>ps2</name><fullname>Sony PlayStation 2</fullname><path>~/ROMs/ps2</path><extension>.iso .chd .ISO .CHD</extension><command>/usr/local/libexec/opi-emulators/ps2 %ROM%</command><platform>ps2</platform><theme>ps2</theme></system>
  <system><name>psp</name><fullname>Sony PSP</fullname><path>~/ROMs/psp</path><extension>.iso .cso .chd .ISO .CSO .CHD</extension><command>/usr/local/libexec/opi-emulators/psp %ROM%</command><platform>psp</platform><theme>psp</theme></system>
  <system><name>n64</name><fullname>Nintendo 64</fullname><path>~/ROMs/n64</path><extension>.z64 .n64 .v64 .zip .Z64 .N64 .V64 .ZIP</extension><command>/usr/local/libexec/opi-emulators/n64 %ROM%</command><platform>n64</platform><theme>n64</theme></system>
  <system><name>dreamcast</name><fullname>Sega Dreamcast</fullname><path>~/ROMs/dreamcast</path><extension>.chd .cdi .gdi .CHD .CDI .GDI</extension><command>/usr/local/libexec/opi-emulators/dreamcast %ROM%</command><platform>dreamcast</platform><theme>dreamcast</theme></system>
  <system><name>gc</name><fullname>Nintendo GameCube</fullname><path>~/ROMs/gc</path><extension>.iso .rvz .gcz .ISO .RVZ .GCZ</extension><command>/usr/local/libexec/opi-emulators/gc %ROM%</command><platform>gc</platform><theme>gc</theme></system>
  <system><name>wii</name><fullname>Nintendo Wii</fullname><path>~/ROMs/wii</path><extension>.iso .rvz .wbfs .ISO .RVZ .WBFS</extension><command>/usr/local/libexec/opi-emulators/wii %ROM%</command><platform>wii</platform><theme>wii</theme></system>
  <system><name>gb</name><fullname>Game Boy</fullname><path>~/ROMs/gb</path><extension>.gb .zip .GB .ZIP</extension><command>/usr/local/libexec/opi-emulators/gb %ROM%</command><platform>gb</platform><theme>gb</theme></system>
  <system><name>gbc</name><fullname>Game Boy Color</fullname><path>~/ROMs/gbc</path><extension>.gbc .zip .GBC .ZIP</extension><command>/usr/local/libexec/opi-emulators/gbc %ROM%</command><platform>gbc</platform><theme>gbc</theme></system>
  <system><name>gba</name><fullname>Game Boy Advance</fullname><path>~/ROMs/gba</path><extension>.gba .zip .GBA .ZIP</extension><command>/usr/local/libexec/opi-emulators/gba %ROM%</command><platform>gba</platform><theme>gba</theme></system>
  <system><name>nds</name><fullname>Nintendo DS</fullname><path>~/ROMs/nds</path><extension>.nds .zip .NDS .ZIP</extension><command>/usr/local/libexec/opi-emulators/nds %ROM%</command><platform>nds</platform><theme>nds</theme></system>
  <system><name>n3ds</name><fullname>Nintendo 3DS</fullname><path>~/ROMs/n3ds</path><extension>.3ds .cci .cxi .3DS .CCI .CXI</extension><command>/usr/local/libexec/opi-emulators/n3ds %ROM%</command><platform>3ds</platform><theme>3ds</theme></system>
  <system><name>nes</name><fullname>Nintendo Entertainment System</fullname><path>~/ROMs/nes</path><extension>.nes .zip .NES .ZIP</extension><command>/usr/local/libexec/opi-emulators/nes %ROM%</command><platform>nes</platform><theme>nes</theme></system>
  <system><name>snes</name><fullname>Super Nintendo</fullname><path>~/ROMs/snes</path><extension>.sfc .smc .zip .SFC .SMC .ZIP</extension><command>/usr/local/libexec/opi-emulators/snes %ROM%</command><platform>snes</platform><theme>snes</theme></system>
  <system><name>ports</name><fullname>Ports</fullname><path>~/ROMs/ports</path><extension>.sh .SH</extension><command>%ROM%</command><platform>pc</platform><theme>ports</theme></system>
</systemList>
EOF

cat > /home/ryan/ROMs/ports/Desktop-Mode.sh <<'EOF'
#!/usr/bin/env bash
exec desktop-mode
EOF
cat > /home/ryan/ROMs/ports/Gaming-Mode.sh <<'EOF'
#!/usr/bin/env bash
exec gaming-mode
EOF
cat > /home/ryan/ROMs/ports/Reboot.sh <<'EOF'
#!/usr/bin/env bash
exec sudo systemctl reboot
EOF
cat > /home/ryan/ROMs/ports/Power-Off.sh <<'EOF'
#!/usr/bin/env bash
exec sudo systemctl poweroff
EOF
cat > /home/ryan/ROMs/ports/Stremio.sh <<'EOF'
#!/usr/bin/env bash
exec stremio
EOF
cat > /home/ryan/ROMs/ports/Moonlight.sh <<'EOF'
#!/usr/bin/env bash
exec moonlight-qt
EOF
chmod 0755 /home/ryan/ROMs/ports/*.sh

for system in ps1 ps2 psp n64 dreamcast gc wii gb gbc gba nds n3ds nes snes; do
    install -d -m0755 -o ryan -g ryan "/home/ryan/ROMs/${system}" "/home/ryan/BIOS/${system}"
done

install -d -m0755 -o ryan -g ryan /home/ryan/.config/mpv
cat > /home/ryan/.config/mpv/mpv.conf <<'EOF'
hwdec=v4l2request-copy
hwdec-codecs=all
vo=gpu-next,gpu
gpu-api=vulkan
keep-open=no
audio-client-name=Stremio
EOF

cat > /usr/local/bin/opi-image-gate <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
media_lib=/opt/opi/media/lib:/opt/opi/media/lib64
required=(
  es-de stremio moonlight-qt gamepad-osk
  duckstation armsx2 ppsspp rmg flycast dolphin-emu sameboy mgba-qt melonds azahar nestopia snes9x-gtk
)
for command_name in "${required[@]}"; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "FAIL: mandatory native command missing: ${command_name}" >&2
    exit 1
  }
done
for file in \
  /opt/stremio/stremio \
  /opt/stremio/server.js \
  /opt/stremio/libopi-stremio-hwdec.so \
  /opt/opi/media/bin/ffmpeg \
  /opt/opi/media/bin/mpv \
  /opt/opi/media/lib/libmpv.so \
  /opt/opi/apps/duckstation/AppRun \
  /opt/opi/apps/armsx2/AppRun \
  /opt/opi/apps/ppsspp/PPSSPPSDL; do
  [[ -e "${file}" ]] || { echo "FAIL: mandatory native file missing: ${file}" >&2; exit 1; }
done
LD_LIBRARY_PATH="${media_lib}" /opt/opi/media/bin/ffmpeg -hide_banner -hwaccels 2>&1 |
  grep -qi v4l2request || { echo "FAIL: FFmpeg lacks v4l2request" >&2; exit 1; }
LD_LIBRARY_PATH="${media_lib}" /opt/opi/media/bin/mpv --no-config --hwdec=help 2>&1 |
  grep -qi v4l2request || { echo "FAIL: mpv lacks v4l2request" >&2; exit 1; }
grep -aFq v4l2request-copy /opt/stremio/stremio || {
  echo "FAIL: Stremio does not contain the forced hardware-decode policy" >&2; exit 1; }
echo "PASS: native applications and the Stremio V4L2 Request path are present"
EOF

cat > /usr/local/bin/opi-stremio-hwcheck <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
media_lib=/opt/opi/media/lib:/opt/opi/media/lib64
mpv=/opt/opi/media/bin/mpv
ffmpeg=/opt/opi/media/bin/ffmpeg
probe_dir=/opt/opi-hw-probes
export LD_LIBRARY_PATH="${media_lib}"

kernel_config="/boot/config-$(uname -r)"
[[ -r "${kernel_config}" ]] || {
  echo "FAIL: running kernel configuration is unavailable: ${kernel_config}" >&2
  exit 1
}
for setting in \
  CONFIG_MEDIA_SUPPORT=m \
  CONFIG_VIDEO_ROCKCHIP_VDEC=m \
  CONFIG_VIDEO_HANTRO=m \
  CONFIG_VSI_IOMMU=y; do
  grep -qx "${setting}" "${kernel_config}" || {
    echo "FAIL: running kernel lacks ${setting}" >&2
    exit 1
  }
done
compgen -G '/dev/video*' >/dev/null || {
  echo "FAIL: no V4L2 video device is exposed by the running kernel" >&2
  exit 1
}
"${ffmpeg}" -hide_banner -hwaccels 2>&1 | grep -qi v4l2request || {
  echo "FAIL: dedicated FFmpeg lacks v4l2request" >&2; exit 1; }

test_probe() {
  local codec="$1" file="$2" log
  [[ -s "${file}" ]] || { echo "FAIL: missing ${codec} probe: ${file}" >&2; return 1; }
  log="$(mktemp)"
  if timeout 90 "${mpv}" --no-config --vo=null --ao=null \
      --hwdec=v4l2request-copy --hwdec-codecs=all --frames=16 \
      --msg-level=all=warn,vd=debug "${file}" >"${log}" 2>&1 &&
      grep -Eqi 'Using hardware decoding.*v4l2request' "${log}"; then
    printf 'PASS: %s used v4l2request-copy\n' "${codec}"
    rm -f "${log}"
    return 0
  fi
  printf 'FAIL: %s did not use v4l2request-copy\n' "${codec}" >&2
  cat "${log}" >&2
  rm -f "${log}"
  return 1
}

test_probe H.264 "${probe_dir}/h264.mp4"
test_probe HEVC-Main10 "${probe_dir}/hevc-main10.mp4"
test_probe H.264-4K "${probe_dir}/h264-4k.mp4"
test_probe HEVC-Main10-4K "${probe_dir}/hevc-main10-4k.mp4"
test_probe VP9-4K "${probe_dir}/vp9-4k.webm"
test_probe AV1-4K "${probe_dir}/av1-4k.mkv"
echo "PASS: RK3588 hardware decoding accepted for every required codec probe"
EOF

cat > /usr/local/bin/opi-stremio-session-check <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
log="${XDG_STATE_HOME:-${HOME}/.local/state}/opi/stremio.log"
[[ -s "${log}" ]] || {
  echo "FAIL: play a video in Stremio first; no playback log exists at ${log}" >&2
  exit 1
}
grep -Eqi 'Using hardware decoding.*v4l2request' "${log}" || {
  echo "FAIL: Stremio playback has no v4l2request hardware-decode evidence" >&2
  exit 1
}
echo "PASS: Stremio's embedded libmpv used v4l2request hardware decoding"
EOF

cat > /usr/local/bin/opi-validate <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
/usr/local/bin/opi-image-gate
/usr/local/bin/opi-stremio-hwcheck
/usr/local/bin/opi-stremio-session-check
echo "PASS: V3.27 Stremio hardware-decode and native-emulator release gates"
EOF
chmod 0755 \
  /usr/local/bin/opi-image-gate \
  /usr/local/bin/opi-stremio-hwcheck \
  /usr/local/bin/opi-stremio-session-check \
  /usr/local/bin/opi-validate

/usr/local/bin/opi-image-gate
chown -R ryan:ryan /home/ryan

update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/brave-browser 200
systemctl enable greetd.service NetworkManager.service bluetooth.service
systemctl disable getty@tty1.service 2>/dev/null || true

apt-get clean
rm -rf /var/lib/apt/lists/*
echo 'V3.27 customization complete'
