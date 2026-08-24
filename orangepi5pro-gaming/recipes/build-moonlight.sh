#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential pkg-config qt6-base-dev qt6-declarative-dev \
  libqt6svg6-dev qt6-wayland \
  libegl1-mesa-dev libgl1-mesa-dev libopus-dev \
  libsdl2-dev libsdl2-ttf-dev libssl-dev \
  libavcodec-dev libavformat-dev libswscale-dev \
  libva-dev libvdpau-dev libxkbcommon-dev \
  wayland-protocols libdrm-dev \
  qml6-module-qtquick-controls qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts qml6-module-qtqml-workerscript \
  qml6-module-qtquick-window qml6-module-qtquick
git clone --recursive --depth=1 --branch "$MOONLIGHT_TAG" \
  https://github.com/moonlight-stream/moonlight-qt.git /src
cd /src
qmake6 moonlight-qt.pro
make -j"$JOBS" release
install -Dm755 app/moonlight /out/rootfs/usr/local/bin/moonlight-qt
mkdir -p /out/rootfs/usr/local/share/moonlight
[[ -f app/SDL_GameControllerDB/gamecontrollerdb.txt ]] &&
  cp -a app/SDL_GameControllerDB/gamecontrollerdb.txt \
    /out/rootfs/usr/local/share/moonlight/gamecontrollerdb.txt || true
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
cat >> /out/runtime-packages.txt <<'RUNTIME'
qml6-module-qtquick-controls
qml6-module-qtquick-templates
qml6-module-qtquick-layouts
qml6-module-qtqml-workerscript
qml6-module-qtquick-window
qml6-module-qtquick
qt6-wayland
RUNTIME
sort -u -o /out/runtime-packages.txt /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
