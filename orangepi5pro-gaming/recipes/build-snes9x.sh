#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git gettext \
  libsdl2-dev libgtkmm-3.0-dev libgtk-3-dev libminizip-dev \
  portaudio19-dev glslang-dev libpulse-dev libasound2-dev \
  libxv-dev libxinerama-dev libwayland-dev
git clone --recursive --depth=1 --branch "$SNES9X_TAG" \
  https://github.com/snes9xgit/snes9x.git /src
cmake -S /src/gtk -B /src/gtk/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build /src/gtk/build --parallel "$JOBS"
DESTDIR=/out/rootfs cmake --install /src/gtk/build || true
if ! find /out/rootfs/usr/local -type f \( -name snes9x-gtk -o -name snes9x \) -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/gtk/build -type f \( -name snes9x-gtk -o -name snes9x \) -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "Snes9x GTK frontend executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/snes9x-gtk
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
