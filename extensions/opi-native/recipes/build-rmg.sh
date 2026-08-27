#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git nasm \
  libusb-1.0-0-dev libhidapi-dev libsamplerate0-dev \
  libspeex-dev libspeexdsp-dev libminizip-dev libsdl3-dev \
  libfreetype-dev libgl1-mesa-dev libglu1-mesa-dev \
  zlib1g-dev binutils-dev qt6-base-dev qt6-websockets-dev \
  qt6-svg-dev libvulkan-dev
ensure_qt6_cmake
git init /src
git -C /src remote add origin https://github.com/Rosalie241/RMG.git
git_net -C /src fetch --depth=1 origin "$RMG_COMMIT"
git -C /src checkout --detach FETCH_HEAD
git_net -C /src submodule update --init --recursive --depth=1
[[ "$(git -C /src rev-parse HEAD)" == "$RMG_COMMIT" ]] || { echo "RMG checkout does not match source lock" >&2; exit 1; }
cmake -S /src -B /src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DPORTABLE_INSTALL=OFF \
  -DUPDATER=OFF -DAPPIMAGE_UPDATER=OFF
cmake --build /src/build --parallel "$JOBS"
DESTDIR=/out/rootfs cmake --install /src/build
if ! find /out/rootfs/usr/local -type f \( -name RMG -o -name rmg \) -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/build -type f \( -name RMG -o -name rmg \) -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "RMG frontend executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/RMG
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
