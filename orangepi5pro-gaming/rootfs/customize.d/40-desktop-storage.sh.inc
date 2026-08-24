log "Desktop browser defaults"
cat > /home/ryan/.config/mimeapps.list <<'EOF'
[Default Applications]
x-scheme-handler/http=org.gnome.Epiphany.desktop
x-scheme-handler/https=org.gnome.Epiphany.desktop
text/html=org.gnome.Epiphany.desktop
application/xhtml+xml=org.gnome.Epiphany.desktop
[Added Associations]
x-scheme-handler/http=org.gnome.Epiphany.desktop;
x-scheme-handler/https=org.gnome.Epiphany.desktop;
text/html=org.gnome.Epiphany.desktop;
EOF
chown ryan:ryan /home/ryan/.config/mimeapps.list
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
