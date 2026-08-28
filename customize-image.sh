#!/usr/bin/env bash
set -Eeuo pipefail

readonly RELEASE="$1"
readonly BOARD="$3"
readonly ASSETS=/tmp/overlay/rootfs

[[ "${RELEASE}" == resolute ]] || { echo "Expected Ubuntu Resolute" >&2; exit 1; }
[[ "${BOARD}" == orangepi5pro ]] || { echo "Expected orangepi5pro" >&2; exit 1; }
[[ -d "${ASSETS}" ]] || { echo "Missing controller-image overlay" >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive

for required in /opt/es-de/ES-DE.AppImage /opt/stremio/stremio /opt/opi/media/bin/ffmpeg \
    /opt/opi/media/bin/mpv /opt/opi/apps/moonlight/moonlight-qt /usr/local/bin/gamepad-osk \
    /opt/opi/apps/ppsspp/PPSSPPSDL /opt/opi/apps/duckstation/AppRun /opt/opi/apps/armsx2/AppRun; do
    [[ -e "${required}" ]] || { echo "Missing native application: ${required}" >&2; exit 1; }
done

normalize_command() {
    local name="$1" candidate
    shift
    command -v "${name}" >/dev/null 2>&1 && return 0
    for candidate in "$@"; do
        [[ -x "${candidate}" ]] || continue
        ln -sf "${candidate}" "/usr/local/bin/${name}"
        return 0
    done
    echo "Missing native command: ${name}" >&2
    exit 1
}

# Ubuntu installs gamescope in /usr/games, which is not in the PATH used by
# Armbian's non-login customization chroot. Provide a stable command path for
# both the build-time check and the greetd session at boot.
normalize_command gamescope /usr/bin/gamescope /usr/games/gamescope

for required_command in greetd tuigreet gamescope labwc foot nm-applet blueman-applet \
    swaybg waybar mako udiskie brave-browser firefox opencode; do
    command -v "${required_command}" >/dev/null 2>&1 || {
        echo "Missing required image package/command: ${required_command}" >&2
        exit 1
    }
done
cp -a "${ASSETS}/." /
glib-compile-schemas /usr/share/glib-2.0/schemas

normalize_command rmg /usr/local/bin/RMG
normalize_command melonds /usr/local/bin/melonDS
normalize_command snes9x-gtk /usr/local/bin/snes9x
normalize_command dolphin-emu /usr/bin/dolphin-emu /usr/games/dolphin-emu
normalize_command sameboy /usr/bin/sameboy /usr/games/sameboy /usr/bin/sameboy-sdl /usr/games/sameboy-sdl
normalize_command mgba-qt /usr/bin/mgba-qt /usr/games/mgba-qt
normalize_command nestopia /usr/bin/nestopia /usr/games/nestopia

id ryan >/dev/null 2>&1 || useradd --create-home --shell /bin/bash --comment Ryan --user-group ryan
printf 'ryan:orangepi\n' | chpasswd
groups=()
for group in sudo audio video render input bluetooth netdev games plugdev; do
    getent group "${group}" >/dev/null 2>&1 && groups+=("${group}")
done
((${#groups[@]})) && usermod -aG "$(IFS=,; echo "${groups[*]}")" ryan
passwd --lock root
rm -f /root/.not_logged_in_yet

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
printf 'Europe/London\n' > /etc/timezone
sed -Ei 's/^# (en_GB.UTF-8 UTF-8)$/\1/' /etc/locale.gen
locale-gen en_GB.UTF-8
printf 'LANG=en_GB.UTF-8\n' > /etc/default/locale

install -d -m0755 /etc/gamepad-osk /etc/opi /etc/greetd /usr/local/libexec/opi-emulators
cp /usr/share/gamepad-osk/config /etc/gamepad-osk/config
sed -Ei 's/^[[:space:]]*toggle_combo[[:space:]]*=.*/toggle_combo = guide+a/' /etc/gamepad-osk/config
if grep -qE '^[[:space:]]*combo_period_ms[[:space:]]*=' /etc/gamepad-osk/config; then
    sed -Ei 's/^[[:space:]]*combo_period_ms[[:space:]]*=.*/combo_period_ms = 200/' /etc/gamepad-osk/config
else
    printf '\ncombo_period_ms = 200\n' >> /etc/gamepad-osk/config
fi
grep -qx 'toggle_combo = guide+a' /etc/gamepad-osk/config || {
    echo 'Controller OSK Guide+A mapping was not installed' >&2
    exit 1
}
printf 'gaming\n' > /etc/opi/session-mode

cat > /usr/local/bin/es-de <<'EOF'
#!/usr/bin/env bash
exec /opt/es-de/ES-DE.AppImage "$@"
EOF
cat > /usr/local/bin/duckstation <<'EOF'
#!/usr/bin/env bash
export APPDIR=/opt/opi/apps/duckstation
cd "${APPDIR}"
exec ./AppRun "$@"
EOF
cat > /usr/local/bin/armsx2 <<'EOF'
#!/usr/bin/env bash
export APPDIR=/opt/opi/apps/armsx2
cd "${APPDIR}"
exec ./AppRun "$@"
EOF
chmod 0755 /usr/local/bin/es-de /usr/local/bin/duckstation /usr/local/bin/armsx2

declare -A emulator=(
    [ps1]='duckstation -batch' [ps2]='armsx2' [psp]='ppsspp' [n64]='rmg'
    [dreamcast]='flycast' [gc]='dolphin-emu -b -e' [wii]='dolphin-emu -b -e'
    [gb]='sameboy' [gbc]='sameboy' [gba]='mgba-qt' [nds]='melonds'
    [nes]='nestopia' [snes]='snes9x-gtk'
)
for system in "${!emulator[@]}"; do
    printf '#!/usr/bin/env bash\nexec opi-run-game %s "$@"\n' "${emulator[$system]}" > "/usr/local/libexec/opi-emulators/${system}"
    chmod 0755 "/usr/local/libexec/opi-emulators/${system}"
    install -d -m0755 -o ryan -g ryan "/home/ryan/ROMs/${system}" "/home/ryan/BIOS/${system}"
done

install -d -m0755 -o ryan -g ryan /home/ryan/.config/opi /home/ryan/.config/labwc \
    /home/ryan/.emulationstation/custom_systems /home/ryan/ROMs/ports
install -m0644 /usr/local/share/opi/es_systems.xml /home/ryan/.emulationstation/custom_systems/es_systems.xml
touch /home/ryan/.config/opi/password-setup-required
cat > /home/ryan/.config/labwc/rc.xml <<'EOF'
<?xml version="1.0"?>
<labwc_config>
  <core><reuseOutputMode>yes</reuseOutputMode></core>
  <keyboard>
    <keybind key="W-Return"><action name="Execute" command="foot"/></keybind>
    <keybind key="W-g"><action name="Execute" command="sudo /usr/local/bin/opi-session set gaming"/></keybind>
  </keyboard>
</labwc_config>
EOF

make_port() {
    local name="$1" command="$2"
    printf '#!/usr/bin/env bash\nexec %s\n' "${command}" > "/home/ryan/ROMs/ports/${name}.sh"
    chmod 0755 "/home/ryan/ROMs/ports/${name}.sh"
}
make_port Desktop 'sudo /usr/local/bin/opi-session set desktop'
make_port Stremio 'opi-controller-app stremio'
make_port Moonlight 'opi-controller-app moonlight-qt'
make_port Brave 'opi-controller-app brave-browser'
make_port Firefox 'opi-controller-app firefox'
make_port OpenCode 'foot -F -e opencode'
make_port Reboot 'sudo /usr/bin/systemctl reboot'
make_port Power-Off 'sudo /usr/bin/systemctl poweroff'

install -d -m0755 -o _greetd -g _greetd /var/cache/tuigreet
cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[general]
runfile = "/run/greetd-opi-initial"

[default_session]
command = "tuigreet --time --remember --cmd 'opi-session gaming'"
user = "_greetd"

[initial_session]
command = "opi-session dispatch"
user = "ryan"
EOF
cat > /etc/sudoers.d/opi-session <<'EOF'
ryan ALL=(root) NOPASSWD: /usr/local/bin/opi-session set gaming, /usr/local/bin/opi-session set direct, /usr/local/bin/opi-session set desktop, /usr/bin/systemctl reboot, /usr/bin/systemctl poweroff
EOF
chmod 0440 /etc/sudoers.d/opi-session

update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/brave-browser 200
systemctl enable greetd.service NetworkManager.service bluetooth.service opi-performance.service
systemctl disable getty@tty1.service 2>/dev/null || true
chown -R ryan:ryan /home/ryan
apt-get clean
rm -rf /var/lib/apt/lists/*
echo 'Controller-first Orange Pi image customization complete'
