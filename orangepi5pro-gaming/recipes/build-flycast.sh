#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git \
  libcurl4-openssl-dev libudev-dev libsdl2-dev \
  libgl1-mesa-dev libvulkan-dev libpulse-dev libasound2-dev \
  libusb-1.0-0-dev
git init /src
git -C /src remote add origin https://github.com/flyinghead/flycast.git
git_net -C /src fetch --depth=1 origin "$FLYCAST_COMMIT"
git -C /src checkout --detach FETCH_HEAD
git_net -C /src submodule update --init --recursive --depth=1
[[ "$(git -C /src rev-parse HEAD)" == "$FLYCAST_COMMIT" ]] || { echo "Flycast checkout does not match source lock" >&2; exit 1; }
cmake -S /src -B /src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build /src/build --parallel "$JOBS"
mkdir -p /out/rootfs/usr/local/bin /out/rootfs/usr/local/share/flycast
DESTDIR=/out/rootfs cmake --install /src/build
if ! find /out/rootfs/usr/local -type f -name flycast -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/build -type f -name flycast -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "Flycast executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/flycast
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
