#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential pkg-config python3 qt6-base-dev qt6-declarative-dev \
  qt6-svg-dev qt6-wayland \
  libegl1-mesa-dev libgl1-mesa-dev libopus-dev \
  libsdl2-dev libsdl2-ttf-dev libssl-dev \
  libva-dev libvdpau-dev libxkbcommon-dev \
  libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  wayland-protocols libdrm-dev \
  qml6-module-qtquick-controls qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts qml6-module-qtqml-workerscript \
  qml6-module-qtquick-window qml6-module-qtquick
ensure_qt6_cmake

git init /src
git -C /src remote add origin https://github.com/moonlight-stream/moonlight-qt.git
git_net -C /src fetch --depth=1 origin "$MOONLIGHT_COMMIT"
git -C /src checkout --detach FETCH_HEAD
git_net -C /src submodule update --init --recursive --depth=1
cd /src

# Keep Moonlight on its normal native FFmpeg/decoder integration. The dedicated
# Stremio FFmpeg/libmpv stack is intentionally not injected here.
SESSION_CPP=/src/app/streaming/session.cpp
if [[ "$(grep -Fc '"FFmpeg-based video decoder chosen"' "$SESSION_CPP")" -eq 1 ]]; then
  sed -i 's/"FFmpeg-based video decoder chosen"/"FFmpeg-based %s video decoder chosen", chosenDecoder->isHardwareAccelerated() ? "hardware-accelerated" : "software"/' "$SESSION_CPP"
fi

qmake6 moonlight-qt.pro
make -j"$JOBS" release

install -Dm755 app/moonlight /out/rootfs/opt/opi/apps/moonlight/moonlight-qt
install -d -m0755 /out/rootfs/usr/local/bin
cat > /out/rootfs/usr/local/bin/moonlight-qt <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
mkdir -p "$HOME/.local/state/opi"
exec /opt/opi/apps/moonlight/moonlight-qt "$@" \
  2> >(tee -a "$HOME/.local/state/opi/moonlight.log" >&2)
WRAPPER
chmod 0755 /out/rootfs/usr/local/bin/moonlight-qt

mkdir -p /out/rootfs/usr/local/share/moonlight
[[ -f app/SDL_GameControllerDB/gamecontrollerdb.txt ]] &&
  cp -a app/SDL_GameControllerDB/gamecontrollerdb.txt \
    /out/rootfs/usr/local/share/moonlight/gamecontrollerdb.txt || true

assert_aarch64_tree /out/rootfs/opt/opi/apps/moonlight
collect_runtime_packages /out/rootfs/opt/opi/apps/moonlight /out/runtime-packages.txt
cat >> /out/runtime-packages.txt <<'RUNTIME'
libsdl2-ttf-2.0-0
libqt6quickcontrols2-6
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
