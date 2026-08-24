log "Native Stremio hardware-decode stack"
test -x /opt/stremio/stremio || { echo "Native Stremio shell missing" >&2; exit 1; }
test -s /opt/stremio/server.js || { echo "Stremio server.js missing or empty" >&2; exit 1; }
test -x /opt/opi/media/bin/mpv || { echo "Custom mpv missing" >&2; exit 1; }
test -e /opt/opi/media/lib/libmpv.so || { echo "Custom libmpv missing from deterministic library path" >&2; exit 1; }
test -x /opt/opi/media/bin/ffmpeg || { echo "Custom FFmpeg missing" >&2; exit 1; }
command -v node >/dev/null || { echo "Ubuntu ARM64 Node.js missing" >&2; exit 1; }
test -f /usr/share/glib-2.0/schemas/com.stremio.Stremio.gschema.xml || { echo "Stremio GSettings schema missing" >&2; exit 1; }
glib-compile-schemas /usr/share/glib-2.0/schemas
install -d -o ryan -g ryan /home/ryan/.config/mpv
cat > /home/ryan/.config/mpv/mpv.conf <<'EOF'
hwdec=v4l2request-copy,auto-safe
vo=gpu-next,gpu
gpu-api=vulkan
gpu-context=waylandvk
keep-open=no
audio-client-name=Stremio
EOF
chown -R ryan:ryan /home/ryan/.config/mpv
cat > /home/ryan/ROMs/ports/Stremio.sh <<'EOF'
#!/usr/bin/env bash
exec stremio
EOF
cat > /home/ryan/ROMs/ports/Moonlight.sh <<'EOF'
#!/usr/bin/env bash
exec moonlight-qt
EOF
chmod 0755 /home/ryan/ROMs/ports/Stremio.sh /home/ryan/ROMs/ports/Moonlight.sh
chown -R ryan:ryan /home/ryan/ROMs/ports

log "Moonlight: 4K-capable, hardware-decode-only defaults"
install -d -o ryan -g ryan "/home/ryan/.config/Moonlight Game Streaming Project"
cat > "/home/ryan/.config/Moonlight Game Streaming Project/Moonlight.conf" <<'EOF'
[General]
width=3840
height=2160
fps=60
videocfg=0
videodec=1
hdr=true
EOF
chown -R ryan:ryan "/home/ryan/.config/Moonlight Game Streaming Project"

log "Steam ARM64 bootstrap"
cat > /usr/local/bin/steam-arm64-bootstrap <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p "$HOME/.local/share/Steam"
if [[ -f /opt/opi-seed/steam-arm64.zip ]]; then
    unzip -o /opt/opi-seed/steam-arm64.zip -d "$HOME/.local/share/Steam"
else
    manifest="$(curl -fsSL https://client-update.steamstatic.com/steam_client_publicbeta_linuxarm64)"
    f="$(grep -oE 'bins_linuxarm64_linuxarm64\.zip\.[0-9a-fA-F]+' <<<"$manifest" | head -n1)"
    [[ -n "$f" ]]
    curl -fL "https://client-update.steamstatic.com/$f" -o /tmp/steam-arm64.zip
    unzip -o /tmp/steam-arm64.zip -d "$HOME/.local/share/Steam"
fi
find "$HOME/.local/share/Steam" -type f -name steam.sh -exec chmod +x {} + 2>/dev/null || true
echo "Steam ARM64 payload installed under $HOME/.local/share/Steam"
EOF
chmod 0755 /usr/local/bin/steam-arm64-bootstrap
cat > /usr/local/bin/install-ge-proton-aarch64 <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
archive=/opt/opi-seed/ge-proton-aarch64.tar.gz
[[ -f "$archive" ]] || { echo "No GE-Proton AArch64 seed in image"; exit 1; }
mkdir -p "$HOME/.steam/root/compatibilitytools.d"
tar -xzf "$archive" -C "$HOME/.steam/root/compatibilitytools.d"
EOF
chmod 0755 /usr/local/bin/install-ge-proton-aarch64
if [[ -f /opt/opi-seed/steam-arm64.zip ]]; then sudo -u ryan -H /usr/local/bin/steam-arm64-bootstrap || true; fi
if [[ -f /opt/opi-seed/ge-proton-aarch64.tar.gz ]]; then sudo -u ryan -H /usr/local/bin/install-ge-proton-aarch64 || true; fi
