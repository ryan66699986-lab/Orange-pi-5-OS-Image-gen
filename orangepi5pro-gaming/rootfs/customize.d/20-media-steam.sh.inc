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

log "Moonlight: display-autodetected, HDR-aware, hardware-decode-only defaults"
install -d -o ryan -g ryan "/home/ryan/.config/Moonlight Game Streaming Project"
cat > "/home/ryan/.config/Moonlight Game Streaming Project/Moonlight.conf" <<'EOF'
[General]
width=1280
height=720
fps=60
videocfg=0
videodec=1
hdr=false
EOF
chown -R ryan:ryan "/home/ryan/.config/Moonlight Game Streaming Project"
cat > /usr/local/bin/opi-moonlight-display-auto <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
cfg="$HOME/.config/Moonlight Game Streaming Project/Moonlight.conf"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opi"
install -d -m0700 "$(dirname "$cfg")" "$state_dir"
json="$(mktemp)"
trap 'rm -f -- "$json"' EXIT
if command -v wlr-randr >/dev/null 2>&1; then
  wlr-randr --json >"$json" 2>/dev/null || printf '[]\n' >"$json"
else
  printf '[]\n' >"$json"
fi
python3 - "$cfg" "$json" "$state_dir/moonlight-display.env" <<'PY'
import glob, json, os, re, subprocess, sys

cfg, json_path, state_path = sys.argv[1:]
width, height, fps, output = 1280, 720, 60, "fallback"
try:
    outputs = json.load(open(json_path, encoding="utf-8"))
except (OSError, ValueError):
    outputs = []
enabled = [item for item in outputs if item.get("enabled")]
if enabled:
    def best_mode(display):
        modes = display.get("modes") or []
        preferred = [item for item in modes if item.get("preferred")]
        pool = preferred or modes
        return max(pool, key=lambda item: (
            int(item.get("width", 0)) * int(item.get("height", 0)),
            int(item.get("refresh", 0)),
        ), default=None)

    ranked = []
    for candidate in enabled:
        candidate_mode = best_mode(candidate)
        if candidate_mode:
            ranked.append((
                int(candidate_mode.get("width", 0)) * int(candidate_mode.get("height", 0)),
                int(candidate_mode.get("refresh", 0)),
                str(candidate.get("name") or ""),
                candidate,
                candidate_mode,
            ))
    if ranked:
        _, _, _, display, mode = max(ranked, key=lambda item: (item[0], item[1], item[2]))
    else:
        display, mode = enabled[0], None
    output = str(display.get("name") or "unknown")
    if mode:
        width = max(1, int(mode.get("width", width)))
        height = max(1, int(mode.get("height", height)))
        refresh = float(mode.get("refresh", fps))
        fps = max(1, round(refresh / 1000 if refresh > 1000 else refresh))
else:
    candidates = []
    for status in glob.glob("/sys/class/drm/card*-*/status"):
        try:
            if open(status, encoding="ascii").read().strip() != "connected":
                continue
            connector = os.path.basename(os.path.dirname(status)).split("-", 1)[-1]
            for raw in open(os.path.join(os.path.dirname(status), "modes"), encoding="ascii"):
                match = re.fullmatch(r"(\d+)x(\d+)", raw.strip())
                if match:
                    w, h = map(int, match.groups())
                    candidates.append((w * h, w, h, connector))
        except OSError:
            pass
    if candidates:
        _, width, height, output = max(candidates)

hdr = False
if output not in ("fallback", "unknown"):
    for edid in glob.glob(f"/sys/class/drm/card*-{output}/edid"):
        try:
            result = subprocess.run(["edid-decode", edid], check=False, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            if "HDR Static Metadata Data Block" in result.stdout:
                hdr = True
                break
        except OSError:
            pass

try:
    lines = open(cfg, encoding="utf-8").read().splitlines()
except OSError:
    lines = ["[General]"]
values = {
    "width": str(width), "height": str(height), "fps": str(fps),
    "videocfg": "0", "videodec": "1", "hdr": str(hdr).lower(),
}
seen = set()
for index, line in enumerate(lines):
    match = re.match(r"^(width|height|fps|videocfg|videodec|hdr)=", line)
    if match:
        key = match.group(1)
        lines[index] = f"{key}={values[key]}"
        seen.add(key)
if not lines or lines[0] != "[General]":
    lines.insert(0, "[General]")
for key, value in values.items():
    if key not in seen:
        lines.append(f"{key}={value}")
tmp = cfg + ".tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")
os.replace(tmp, cfg)
with open(state_path, "w", encoding="utf-8") as handle:
    handle.write(f"EXPECTED_WIDTH={width}\nEXPECTED_HEIGHT={height}\nEXPECTED_FPS={fps}\n")
    handle.write(f"HDR_DETECTED={str(hdr).lower()}\nOUTPUT_NAME={output}\n")
print(f"Moonlight display policy: {width}x{height}@{fps}, HDR={str(hdr).lower()}, output={output}")
PY
EOF
chmod 0755 /usr/local/bin/opi-moonlight-display-auto

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
