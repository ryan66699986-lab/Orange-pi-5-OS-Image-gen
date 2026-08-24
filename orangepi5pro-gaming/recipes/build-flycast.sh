#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git \
  libcurl4-openssl-dev libudev-dev libsdl2-dev \
  libgl1-mesa-dev libvulkan-dev libpulse-dev libasound2-dev \
  libusb-1.0-0-dev
git clone --recursive --depth=1 --branch "$FLYCAST_TAG" \
  https://github.com/flyinghead/flycast.git /src
cmake -S /src -B /src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build /src/build --parallel "$JOBS"
mkdir -p /out/rootfs/usr/local/bin /out/rootfs/usr/local/share/flycast
DESTDIR=/out/rootfs cmake --install /src/build || true
if ! find /out/rootfs/usr/local -type f -name flycast -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/build -type f -name flycast -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "Flycast executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/flycast
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
