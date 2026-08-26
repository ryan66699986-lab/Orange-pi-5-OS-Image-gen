#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
source /arm64-common.sh

sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update >/dev/null
mapfile -t required_packages < /required-packages.txt
(( ${#required_packages[@]} > 20 )) || { echo "Runtime package input is implausibly small" >&2; exit 1; }
apt-get install -y --no-install-recommends "${required_packages[@]}" >/dev/null
cp -a /overlay/. /
ldconfig

for pkg in libsdl3-0 libsdl3-ttf0 libglew2.2; do
  dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -qx 'install ok installed' || {
    echo "Merged runtime preflight lacks mandatory explicit runtime package: $pkg" >&2
    exit 1
  }
done

ppsspp_linkage="$(checked_ldd /opt/opi/apps/ppsspp/PPSSPPSDL /opt/opi/media/lib:/opt/opi/media/lib64)"
grep -Eq 'libGLEW[.]so[.]2[.]2[[:space:]]+=>[[:space:]]+/' <<<"$ppsspp_linkage" || {
  printf '%s\n' "$ppsspp_linkage" >&2
  echo "PPSSPP does not resolve libGLEW.so.2.2 in merged runtime preflight" >&2
  exit 1
}

critical=(/usr/local/bin/gamepad-osk /opt/opi/apps/moonlight/moonlight-qt /opt/opi/apps/ppsspp/PPSSPPSDL /opt/stremio/stremio /opt/opi/media/bin/mpv /opt/opi/media/bin/ffmpeg)
for path in "${critical[@]}"; do
  [[ -x "$path" ]] || { echo "Critical merged executable missing: $path" >&2; exit 1; }
done

appimage_roots=(/opt/opi/apps/duckstation /opt/opi/apps/armsx2)
for root in "${appimage_roots[@]}"; do
  [[ -x "$root/AppRun" ]] || { echo "Extracted AppImage launcher missing: $root/AppRun" >&2; exit 1; }
done

checked=0
while IFS= read -r -d '' path; do
  elf_has_needed "$path" || continue
  checked_ldd "$path" /opt/opi/media/lib:/opt/opi/media/lib64 >/dev/null
  checked=$((checked + 1))
done < <(find /usr/local /opt/stremio /opt/opi/media /opt/opi/apps/ppsspp /opt/opi/apps/moonlight -type f -print0)
(( checked >= 10 )) || { echo "Runtime closure preflight inspected only $checked dynamic ELF files" >&2; exit 1; }

appimage_checked=0
for root in "${appimage_roots[@]}"; do
  appimage_library_path="$({ find "$root" -type f \( -name '*.so' -o -name '*.so.*' \) -printf '%h\n' 2>/dev/null || true; } | sort -u | paste -sd: -)"
  while IFS= read -r -d '' path; do
    elf_has_needed "$path" || continue
    checked_ldd "$path" "${appimage_library_path:+${appimage_library_path}:}/opt/opi/media/lib:/opt/opi/media/lib64" >/dev/null
    appimage_checked=$((appimage_checked + 1))
  done < <(find "$root" -type f -perm /111 -print0)
done
(( appimage_checked >= 2 )) || { echo "AppImage runtime closure inspected only $appimage_checked dynamic ELF files" >&2; exit 1; }

gamepad_linkage="$(checked_ldd /usr/local/bin/gamepad-osk /opt/opi/media/lib:/opt/opi/media/lib64)"
for soname in libSDL3.so.0 libSDL3_ttf.so.0; do
  grep -Eq "${soname//./[.]}[[:space:]]+=>[[:space:]]+/" <<<"$gamepad_linkage" || {
    printf '%s\n' "$gamepad_linkage" >&2
    echo "gamepad-osk does not resolve $soname in merged runtime preflight" >&2
    exit 1
  }
done

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

package_count="$(wc -l < /runtime-packages.closure.txt)"
package_sha256="$(sha256sum /runtime-packages.closure.txt | awk '{print $1}')"
(( package_count >= 5 )) || { echo "ELF closure derived only $package_count owning packages" >&2; exit 1; }
{
  echo 'schema=opi-runtime-closure-v2'
  echo 'architecture=arm64'
  printf 'core_dynamic_elf_count=%s\n' "$checked"
  printf 'appimage_dynamic_elf_count=%s\n' "$appimage_checked"
  printf 'package_count=%s\n' "$package_count"
  printf 'package_sha256=%s\n' "$package_sha256"
  echo 'result=PASS'
} > /runtime-closure.receipt
echo "ARM64 merged-artifact runtime closure: PASS ($checked core + $appimage_checked AppImage dynamic ELF files; $package_count packages)"
