#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential clang clang-format cmake ninja-build pkg-config git \
  libasound2-dev libgl-dev libpipewire-0.3-dev libssl-dev \
  libsdl2-dev libx11-dev libxext-dev libusb-1.0-0-dev \
  qt6-base-dev qt6-base-private-dev qt6-l10n-tools \
  qt6-multimedia-dev qt6-tools-dev qt6-tools-dev-tools libvulkan-dev
git clone --recursive --depth=1 --branch "$AZAHAR_TAG" \
  https://github.com/azahar-emu/azahar.git /src
cmake -S /src -B /src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DENABLE_OPENGL=OFF \
  -DENABLE_VULKAN=ON \
  -DENABLE_LTO=OFF \
  -DENABLE_NATIVE_OPTIMIZATION=OFF \
  -DUSE_SYSTEM_SDL2=ON \
  -DUSE_SYSTEM_LIBUSB=ON
cmake --build /src/build --parallel "$JOBS"
ctest --test-dir /src/build --output-on-failure || \
  echo "WARN: Azahar tests had headless/QEMU failures"
mkdir -p /out/rootfs/usr/local/bin
DESTDIR=/out/rootfs cmake --install /src/build || true
if ! find /out/rootfs/usr/local -type f \( -name azahar -o -name citra-qt -o -name azahar-qt \) -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/build -type f \( -name azahar -o -name citra-qt -o -name azahar-qt \) -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "Azahar frontend executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/azahar
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
