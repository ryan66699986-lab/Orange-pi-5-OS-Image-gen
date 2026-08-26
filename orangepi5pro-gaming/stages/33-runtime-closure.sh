say "ARM64 merged-artifact runtime closure preflight"
docker run --rm --platform linux/arm64 \
  -v "$OVERLAY:/overlay:ro" \
  -v "$WORK/required-packages.txt:/required-packages.txt:ro" \
  ubuntu:26.04 bash -seu <<'RUNTIME_CLOSURE'
export DEBIAN_FRONTEND=noninteractive
sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' \
  /etc/apt/sources.list.d/ubuntu.sources
apt-get update >/dev/null
mapfile -t required_packages < /required-packages.txt
apt-get install -y --no-install-recommends "${required_packages[@]}" >/dev/null
cp -a /overlay/. /
ldconfig

for pkg in libsdl3-0 libsdl3-ttf0; do
  dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -qx 'install ok installed' || {
    echo "Merged runtime preflight lacks mandatory gamepad-osk package: $pkg" >&2
    exit 1
  }
done

critical=(
  /usr/local/bin/gamepad-osk
  /opt/opi/apps/moonlight/moonlight-qt
  /opt/opi/apps/ppsspp/PPSSPPSDL
  /opt/stremio/stremio
  /opt/opi/media/bin/mpv
  /opt/opi/media/bin/ffmpeg
)
for path in "${critical[@]}"; do
  [[ -x "$path" ]] || { echo "Critical merged executable missing: $path" >&2; exit 1; }
done

appimage_roots=(/opt/opi/apps/duckstation /opt/opi/apps/armsx2)
for root in "${appimage_roots[@]}"; do
  [[ -x "$root/AppRun" ]] || { echo "Extracted AppImage launcher missing: $root/AppRun" >&2; exit 1; }
done
appimage_library_path="$({ find "${appimage_roots[@]}" -type f \( -name '*.so' -o -name '*.so.*' \) -printf '%h\n' 2>/dev/null || true; } | sort -u | paste -sd: -)"

checked=0
while IFS= read -r -d '' path; do
  file -Lb "$path" | grep -q '^ELF' || continue
  LD_LIBRARY_PATH="${appimage_library_path:+${appimage_library_path}:}/opt/opi/media/lib:/opt/opi/media/lib64" ldd "$path" > /tmp/opi-runtime-ldd.txt 2>&1 || true
  if grep -q 'not found' /tmp/opi-runtime-ldd.txt; then
    echo "Unresolved shared library before Armbian build: $path" >&2
    cat /tmp/opi-runtime-ldd.txt >&2
    exit 1
  fi
  checked=$((checked + 1))
done < <(find /usr/local /opt/stremio /opt/opi/media /opt/opi/apps/ppsspp /opt/opi/apps/moonlight -type f -print0)
(( checked >= 10 )) || { echo "Runtime closure preflight inspected only $checked ELF files" >&2; exit 1; }

appimage_checked=0
while IFS= read -r -d '' path; do
  file -Lb "$path" | grep -q '^ELF' || continue
  LD_LIBRARY_PATH="${appimage_library_path:+${appimage_library_path}:}/opt/opi/media/lib:/opt/opi/media/lib64" ldd "$path" > /tmp/opi-appimage-ldd.txt 2>&1 || true
  if grep -q 'not found' /tmp/opi-appimage-ldd.txt; then
    echo "Unresolved executable dependency in extracted AppImage: $path" >&2
    cat /tmp/opi-appimage-ldd.txt >&2
    exit 1
  fi
  appimage_checked=$((appimage_checked + 1))
done < <(find "${appimage_roots[@]}" -type f -perm /111 -print0)
(( appimage_checked >= 2 )) || { echo "AppImage runtime closure inspected only $appimage_checked executable ELF files" >&2; exit 1; }

LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd /usr/local/bin/gamepad-osk > /tmp/gamepad-osk-ldd.txt
for soname in libSDL3.so.0 libSDL3_ttf.so.0; do
  grep -Eq "${soname//./[.]}[[:space:]]+=>[[:space:]]+/" /tmp/gamepad-osk-ldd.txt || {
    cat /tmp/gamepad-osk-ldd.txt >&2
    echo "gamepad-osk does not resolve $soname in merged runtime preflight" >&2
    exit 1
  }
done
echo "ARM64 merged-artifact runtime closure: PASS ($checked core + $appimage_checked AppImage executable ELF files)"
RUNTIME_CLOSURE
good "Merged ARM64 artifact runtime closure is complete"
