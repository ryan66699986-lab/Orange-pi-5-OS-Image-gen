log "Controller-wide OSK configuration"
install -d -m0755 /etc/gamepad-osk
cp /usr/share/gamepad-osk/config /etc/gamepad-osk/config 2>/dev/null || : > /etc/gamepad-osk/config
if grep -qE '^[[:space:]]*toggle_combo[[:space:]]*=' /etc/gamepad-osk/config; then
    sed -Ei 's/^[[:space:]]*toggle_combo[[:space:]]*=.*/toggle_combo = guide+a/' /etc/gamepad-osk/config
elif grep -qE '^\[gamepad\][[:space:]]*$' /etc/gamepad-osk/config; then
    sed -i '/^\[gamepad\][[:space:]]*$/a toggle_combo = guide+a' /etc/gamepad-osk/config
else
    printf '\n[gamepad]\ntoggle_combo = guide+a\n' >> /etc/gamepad-osk/config
fi
if grep -qE '^[[:space:]]*combo_period_ms[[:space:]]*=' /etc/gamepad-osk/config; then
    sed -Ei 's/^[[:space:]]*combo_period_ms[[:space:]]*=.*/combo_period_ms = 200/' /etc/gamepad-osk/config
else
    sed -i '/^[[:space:]]*toggle_combo[[:space:]]*= guide+a/a combo_period_ms = 200' /etc/gamepad-osk/config
fi

log "Native Wayland session stack"
cat > /usr/local/bin/opi-gaming-child <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p "$HOME/.local/state/opi"
gamepad-osk --daemon --config /etc/gamepad-osk/config >>"$HOME/.local/state/opi/gamepad-osk.log" 2>&1 &
/usr/local/bin/opi-rom-scan || true
exec es-de
EOF
chmod 0755 /usr/local/bin/opi-gaming-child
cat > /usr/local/bin/opi-gaming-session <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=opi-gaming
export XDG_CURRENT_DESKTOP=gamescope
export SDL_AUDIODRIVER=pipewire
export SDL_VIDEODRIVER=wayland,x11
export QT_QPA_PLATFORM='wayland;xcb'
export MOZ_ENABLE_WAYLAND=1
mkdir -p "$HOME/.local/state/opi"
set +e
gamescope -f -- /usr/local/bin/opi-gaming-child 2> >(tee -a "$HOME/.local/state/opi/gamescope.log" >&2)
rc=$?
set -e
printf 'Gamescope exited with status %s; falling back to Labwc Desktop Mode\n' "$rc" >> "$HOME/.local/state/opi/gamescope.log"
exec /usr/local/bin/opi-desktop-session
EOF
chmod 0755 /usr/local/bin/opi-gaming-session
cat > /usr/local/bin/opi-labwc-startup <<'EOF'
#!/usr/bin/env bash
set -u
swaybg -c '#20242b' >/dev/null 2>&1 &
waybar >/dev/null 2>&1 &
nm-applet --indicator >/dev/null 2>&1 &
blueman-applet >/dev/null 2>&1 &
mako >/dev/null 2>&1 &
udiskie --automount --notify >/dev/null 2>&1 &
gamepad-osk --daemon --config /etc/gamepad-osk/config >/dev/null 2>&1 &
if [[ -x /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 ]]; then
    /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &
fi
EOF
chmod 0755 /usr/local/bin/opi-labwc-startup
cat > /usr/local/bin/opi-desktop-session <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=labwc
export XDG_CURRENT_DESKTOP=labwc
export SDL_AUDIODRIVER=pipewire
export SDL_VIDEODRIVER=wayland,x11
export QT_QPA_PLATFORM='wayland;xcb'
export MOZ_ENABLE_WAYLAND=1
exec labwc -s /usr/local/bin/opi-labwc-startup
EOF
chmod 0755 /usr/local/bin/opi-desktop-session
install -d -m0755 /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/opi-gaming.desktop <<'EOF'
[Desktop Entry]
Name=OPi Gaming Mode
Comment=Gamescope + ES-DE controller-first session
Exec=/usr/local/bin/opi-gaming-session
Type=Application
DesktopNames=OPiGaming
EOF
cat > /usr/share/wayland-sessions/opi-labwc.desktop <<'EOF'
[Desktop Entry]
Name=OPi Labwc Desktop
Comment=Lightweight Wayland desktop
Exec=/usr/local/bin/opi-desktop-session
Type=Application
DesktopNames=Labwc
EOF
install -d -o ryan -g ryan /home/ryan/.config/labwc
cat > /home/ryan/.config/labwc/rc.xml <<'EOF'
<?xml version="1.0"?>
<labwc_config><core><reuseOutputMode>yes</reuseOutputMode><xwaylandPersistence>no</xwaylandPersistence></core><keyboard><keybind key="W-Return"><action name="Execute" command="kitty"/></keybind><keybind key="W-d"><action name="Execute" command="fuzzel"/></keybind><keybind key="W-e"><action name="Execute" command="pcmanfm-qt"/></keybind><keybind key="W-g"><action name="Execute" command="gaming-mode"/></keybind></keyboard></labwc_config>
EOF
install -d -o ryan -g ryan /home/ryan/.config/waybar
cat > /home/ryan/.config/waybar/config.jsonc <<'EOF'
{"layer":"top","position":"top","height":34,"modules-left":["custom/launcher","wlr/taskbar"],"modules-center":["clock"],"modules-right":["network","pulseaudio","tray"],"custom/launcher":{"format":" Applications ","on-click":"fuzzel"},"clock":{"format":"{:%a %d %b  %H:%M}"},"network":{"format-wifi":"{essid}  {signalStrength}%","format-ethernet":"Ethernet","format-disconnected":"Offline","on-click":"nm-connection-editor"},"pulseaudio":{"format":"Vol {volume}%","format-muted":"Muted","on-click":"pavucontrol"}}
EOF
cat > /home/ryan/.config/waybar/style.css <<'EOF'
* { font-family: "Noto Sans", sans-serif; font-size: 14px; }
window#waybar { background: rgba(28, 31, 36, 0.96); }
#custom-launcher, #clock, #network, #pulseaudio, #tray { padding: 0 10px; }
EOF
install -d -m0755 /etc/opi /etc/greetd
printf '%s\n' gaming > /etc/opi/session-mode
cat > /usr/local/bin/opi-session-dispatch <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
mode="$(cat /etc/opi/session-mode 2>/dev/null || echo gaming)"
case "$mode" in gaming) exec /usr/local/bin/opi-gaming-session ;; desktop) exec /usr/local/bin/opi-desktop-session ;; *) exec /usr/local/bin/opi-gaming-session ;; esac
EOF
chmod 0755 /usr/local/bin/opi-session-dispatch
cat > /usr/local/sbin/opi-set-session <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in gaming|desktop) mode="$1" ;; *) echo "Usage: opi-set-session gaming|desktop" >&2; exit 2 ;; esac
printf '%s\n' "$mode" > /etc/opi/session-mode
rm -f /run/greetd-opi-initial
EOF
chmod 0755 /usr/local/sbin/opi-set-session
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
cat > /usr/local/bin/gaming-mode <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
sudo /usr/local/sbin/opi-set-session gaming
sudo systemctl restart greetd
EOF
cat > /usr/local/bin/desktop-mode <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
sudo /usr/local/sbin/opi-set-session desktop
sudo systemctl restart greetd
EOF
chmod 0755 /usr/local/bin/gaming-mode /usr/local/bin/desktop-mode
chown -R ryan:ryan /home/ryan/.config
