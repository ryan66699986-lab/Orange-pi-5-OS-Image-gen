#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
ESDE_COMMIT="$ESDE_COMMIT"
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build gettext pkg-config \
  libharfbuzz-dev libicu-dev libsdl2-dev \
  libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev \
  libfreeimage-dev libfreetype6-dev libgit2-dev \
  libcurl4-gnutls-dev libpugixml-dev libbluetooth-dev \
  libpoppler-cpp-dev libasound2-dev libgles2-mesa-dev
git clone --depth=1 --branch "$ESDE_TAG" https://gitlab.com/es-de/emulationstation-de.git /src
[[ "$(git -C /src rev-parse HEAD)" == "$ESDE_COMMIT" ]] || { echo "ES-DE checkout commit does not match resolved tag commit" >&2; exit 1; }
cmake -S /src -B /src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DGLES=ON -DGL=OFF \
  -DDEINIT_ON_LAUNCH=ON \
  -DVIDEO_HW_DECODING=ON \
  -DAPPLICATION_UPDATER=OFF
cmake --build /src/build --parallel "$JOBS"
DESTDIR=/out/rootfs cmake --install /src/build || true
if ! find /out/rootfs/usr/local -type f -name es-de -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/build -type f -name es-de -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "ES-DE frontend executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/es-de
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
