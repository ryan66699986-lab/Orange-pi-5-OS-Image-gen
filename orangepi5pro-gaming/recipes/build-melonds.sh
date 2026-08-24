#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build extra-cmake-modules pkg-config git \
  libcurl4-gnutls-dev libpcap0.8-dev libsdl2-dev libarchive-dev \
  libenet-dev libzstd-dev libfaad-dev \
  qt6-base-dev qt6-base-private-dev qt6-multimedia-dev libqt6svg6-dev
git clone --recursive --depth=1 --branch "$MELONDS_TAG" \
  https://github.com/melonDS-emu/melonDS.git /src
cmake -S /src -B /src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build /src/build --parallel "$JOBS"
DESTDIR=/out/rootfs cmake --install /src/build || true
if ! find /out/rootfs/usr/local -type f -iname 'melonDS' -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/build -type f -iname 'melonDS' -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "melonDS frontend executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/melonDS
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
