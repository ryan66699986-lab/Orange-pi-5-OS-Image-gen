say "ARM64 merged-artifact runtime closure preflight"
CLOSURE_PKGS="$WORK/runtime-packages.closure.txt"
: > "$CLOSURE_PKGS"
docker run --rm --platform linux/arm64 \
  -v "$OVERLAY:/overlay:ro" \
  -v "$WORK/required-packages.txt:/required-packages.txt:ro" \
  -v "$SCRIPTS/arm64-common.sh:/arm64-common.sh:ro" \
  -v "$CLOSURE_PKGS:/runtime-packages.closure.txt" \
  ubuntu:26.04 bash -seu <<'RUNTIME_CLOSURE'
export DEBIAN_FRONTEND=noninteractive
source /arm64-common.sh
sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' \
  /etc/apt/sources.list.d/ubuntu.sources
apt-get update >/dev/null
mapfile -t required_packages < /required-packages.txt
apt-get install -y --no-install-recommends "${required_packages[@]}" >/dev/null
cp -a /overlay/. /
ldconfig

for pkg in libsdl3-0 libsdl3-ttf0 libglew2.2; do
  dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -qx 'install ok installed' || {
    echo "Merged runtime preflight lacks mandatory explicit runtime package: $pkg" >&2
    exit 1
  }
done

LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd /opt/opi/apps/ppsspp/PPSSPPSDL > /tmp/ppsspp-ldd.txt
grep -Eq 'libGLEW[.]so[.]2[.]2[[:space:]]+=>[[:space:]]+/' /tmp/ppsspp-ldd.txt || {
  cat /tmp/ppsspp-ldd.txt >&2
  echo "PPSSPP does not resolve libGLEW.so.2.2 in merged runtime preflight" >&2
  exit 1
}

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

checked=0
while IFS= read -r -d '' path; do
  file -Lb "$path" | grep -q '^ELF' || continue
  LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd "$path" > /tmp/opi-runtime-ldd.txt 2>&1 || true
  if grep -q 'not found' /tmp/opi-runtime-ldd.txt; then
    echo "Unresolved shared library before Armbian build: $path" >&2
    cat /tmp/opi-runtime-ldd.txt >&2
    exit 1
  fi
  checked=$((checked + 1))
done < <(find /usr/local /opt/stremio /opt/opi/media /opt/opi/apps/ppsspp /opt/opi/apps/moonlight -type f -print0)
(( checked >= 10 )) || { echo "Runtime closure preflight inspected only $checked ELF files" >&2; exit 1; }

appimage_checked=0
for root in "${appimage_roots[@]}"; do
  appimage_library_path="$({ find "$root" -type f \( -name '*.so' -o -name '*.so.*' \) -printf '%h\n' 2>/dev/null || true; } | sort -u | paste -sd: -)"
  while IFS= read -r -d '' path; do
    file -Lb "$path" | grep -q '^ELF' || continue
    LD_LIBRARY_PATH="${appimage_library_path:+${appimage_library_path}:}/opt/opi/media/lib:/opt/opi/media/lib64" ldd "$path" > /tmp/opi-appimage-ldd.txt 2>&1 || true
    if grep -q 'not found' /tmp/opi-appimage-ldd.txt; then
      echo "Unresolved executable dependency in extracted AppImage: $path" >&2
      cat /tmp/opi-appimage-ldd.txt >&2
      exit 1
    fi
    appimage_checked=$((appimage_checked + 1))
  done < <(find "$root" -type f -perm /111 -print0)
done
(( appimage_checked >= 2 )) || { echo "AppImage runtime closure inspected only $appimage_checked executable ELF files" >&2; exit 1; }

LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd /usr/local/bin/gamepad-osk > /tmp/gamepad-osk-ldd.txt
for soname in libSDL3.so.0 libSDL3_ttf.so.0; do
  grep -Eq "${soname//./[.]}[[:space:]]+=>[[:space:]]+/" /tmp/gamepad-osk-ldd.txt || {
    cat /tmp/gamepad-osk-ldd.txt >&2
    echo "gamepad-osk does not resolve $soname in merged runtime preflight" >&2
    exit 1
  }
done

# Convert the successful ELF closure into an explicit package contract. This
# prevents a library that arrived only as an incidental dependency in this
# clean container from disappearing in Armbian's already-populated rootfs.
# Core applications and AppImages deliberately use separate search paths so a
# bundled AppImage library cannot accidentally satisfy a core application.
core_runtime_roots=(/usr/local /opt/stremio /opt/opi/media /opt/opi/apps/ppsspp /opt/opi/apps/moonlight)
derived_files=()
index=0
export RUNTIME_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64
for root in "${core_runtime_roots[@]}"; do
  derived="/tmp/opi-runtime-packages-${index}.txt"
  collect_runtime_packages "$root" "$derived"
  derived_files+=("$derived")
  index=$((index + 1))
done
for root in "${appimage_roots[@]}"; do
  appimage_library_path="$({ find "$root" -type f \( -name '*.so' -o -name '*.so.*' \) -printf '%h\n' 2>/dev/null || true; } | sort -u | paste -sd: -)"
  export RUNTIME_LIBRARY_PATH="${appimage_library_path:+${appimage_library_path}:}/opt/opi/media/lib:/opt/opi/media/lib64"
  derived="/tmp/opi-runtime-packages-${index}.txt"
  collect_runtime_packages "$root" "$derived"
  derived_files+=("$derived")
  index=$((index + 1))
done
cat "${derived_files[@]}" | sed '/^[[:space:]]*$/d' | sort -u > /runtime-packages.closure.txt
[[ -s /runtime-packages.closure.txt ]] || { echo "ELF closure produced no owning runtime packages" >&2; exit 1; }
if grep -Ev '^[a-z0-9][a-z0-9+.-]*(:[a-z0-9]+)?$' /runtime-packages.closure.txt | grep -q .; then
  echo "ELF closure produced a malformed package name" >&2
  exit 1
fi
echo "ARM64 merged-artifact runtime closure: PASS ($checked core + $appimage_checked AppImage executable ELF files)"
RUNTIME_CLOSURE
cat "$CLOSURE_PKGS" >> "$WORK/required-packages.txt"
sort -u -o "$WORK/required-packages.txt" "$WORK/required-packages.txt"
[[ -s "$WORK/required-packages.txt" ]] || die "Final explicit runtime package contract is empty"
good "Merged ARM64 artifact runtime closure is complete"
