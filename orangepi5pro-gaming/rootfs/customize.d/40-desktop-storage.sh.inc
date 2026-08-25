log "Controller-accessible Brave default and Firefox alternative"
cat > /usr/local/bin/opi-brave <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export GTK_USE_PORTAL=1
exec brave-browser --ozone-platform-hint=auto "$@"
EOF
cat > /usr/local/bin/opi-firefox <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export MOZ_ENABLE_WAYLAND=1
exec firefox "$@"
EOF
chmod 0755 /usr/local/bin/opi-brave /usr/local/bin/opi-firefox
cat > /home/ryan/.config/mimeapps.list <<'EOF'
[Default Applications]
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
text/html=brave-browser.desktop
application/xhtml+xml=brave-browser.desktop
[Added Associations]
x-scheme-handler/http=brave-browser.desktop;firefox.desktop;
x-scheme-handler/https=brave-browser.desktop;firefox.desktop;
text/html=brave-browser.desktop;firefox.desktop;
EOF
chown ryan:ryan /home/ryan/.config/mimeapps.list
cat > /home/ryan/ROMs/ports/Brave-Browser.sh <<'EOF'
#!/usr/bin/env bash
exec opi-brave
EOF
cat > /home/ryan/ROMs/ports/Firefox-Browser.sh <<'EOF'
#!/usr/bin/env bash
exec opi-firefox
EOF
cat > /home/ryan/ROMs/ports/Network-Setup.sh <<'EOF'
#!/usr/bin/env bash
exec nm-connection-editor
EOF
cat > /home/ryan/ROMs/ports/Audio-Settings.sh <<'EOF'
#!/usr/bin/env bash
exec pavucontrol
EOF
chmod 0755 /home/ryan/ROMs/ports/Brave-Browser.sh /home/ryan/ROMs/ports/Firefox-Browser.sh \
    /home/ryan/ROMs/ports/Network-Setup.sh /home/ryan/ROMs/ports/Audio-Settings.sh
chown -R ryan:ryan /home/ryan/ROMs/ports
log "USB ROM discovery"
cat > /usr/local/bin/opi-rom-scan <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
systems=(ps1 ps2 psp n64 dreamcast gc wii gb gbc gba nds n3ds nes snes ports)
base="$HOME/ROMs"
find "$base" -mindepth 2 -maxdepth 2 -type l ! -exec test -e {} \; -delete 2>/dev/null || true
shopt -s nullglob
roots=(/run/media/"$USER"/*/ROMs /media/"$USER"/*/ROMs)
for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  for sys in "${systems[@]}"; do
    [[ -d "$root/$sys" ]] || continue
    mkdir -p "$base/$sys"
    while IFS= read -r -d '' f; do
      name="${f##*/}"
      [[ -e "$base/$sys/$name" || -L "$base/$sys/$name" ]] && continue
      ln -s "$f" "$base/$sys/$name"
    done < <(find "$root/$sys" -maxdepth 1 -type f -print0)
  done
done
EOF
chmod 0755 /usr/local/bin/opi-rom-scan
install -d -m0755 /etc/systemd/user
cat > /etc/systemd/user/opi-rom-scan.service <<'EOF'
[Unit]
Description=Discover ROMs on mounted USB storage
[Service]
Type=oneshot
ExecStart=/usr/local/bin/opi-rom-scan
EOF
cat > /etc/systemd/user/opi-rom-scan.timer <<'EOF'
[Unit]
Description=Periodically discover USB ROM libraries
[Timer]
OnBootSec=20s
OnUnitActiveSec=30s
Unit=opi-rom-scan.service
[Install]
WantedBy=timers.target
EOF
log "Kitty/OpenCode defaults"
update-alternatives --set x-terminal-emulator /usr/bin/kitty 2>/dev/null || true
install -d -o ryan -g ryan /home/ryan/.config/kitty
cat > /home/ryan/.config/kitty/kitty.conf <<'EOF'
enable_audio_bell no
copy_on_select clipboard
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
EOF
chown -R ryan:ryan /home/ryan/.config/kitty
