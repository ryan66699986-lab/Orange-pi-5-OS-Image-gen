#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential pkg-config python3 qt6-base-dev qt6-declarative-dev \
  libqt6svg6-dev qt6-wayland \
  libegl1-mesa-dev libgl1-mesa-dev libopus-dev \
  libsdl2-dev libsdl2-ttf-dev libssl-dev \
  libva-dev libvdpau-dev libxkbcommon-dev \
  wayland-protocols libdrm-dev \
  qml6-module-qtquick-controls qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts qml6-module-qtqml-workerscript \
  qml6-module-qtquick-window qml6-module-qtquick
git init /src
git -C /src remote add origin https://github.com/moonlight-stream/moonlight-qt.git
git_net -C /src fetch --depth=1 origin "$MOONLIGHT_COMMIT"
git -C /src checkout --detach FETCH_HEAD
git_net -C /src submodule update --init --recursive --depth=1
cd /src
[[ "$(git rev-parse HEAD)" == "$MOONLIGHT_COMMIT" ]] || {
  echo "Moonlight checkout does not match resolved source lock" >&2
  exit 1
}

[[ -x /opt/opi/media/bin/ffmpeg && -e /opt/opi/media/lib/libavcodec.so ]] || {
  echo "Dedicated V4L2 Request FFmpeg stack was not mounted for Moonlight" >&2
  exit 1
}
export PATH="/opt/opi/media/bin:$PATH"
export PKG_CONFIG_PATH="/opt/opi/media/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="/opt/opi/media/lib:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="/opt/opi/media/lib:${LIBRARY_PATH:-}"
export CPPFLAGS="-I/opt/opi/media/include ${CPPFLAGS:-}"
export LDFLAGS="-L/opt/opi/media/lib -Wl,-rpath,/opt/opi/media/lib ${LDFLAGS:-}"

ffmpeg -hide_banner -hwaccels 2>&1 | grep -qi v4l2request || {
  echo "Moonlight build input does not expose v4l2request" >&2
  exit 1
}
for pc in libavcodec libavutil libswscale; do
  pc_prefix="$(pkg-config --variable=prefix "$pc")"
  [[ "$pc_prefix" == /opt/opi/media ]] || {
    echo "Moonlight would use non-project $pc from ${pc_prefix:-unknown}" >&2
    exit 1
  }
done

# Emit an unambiguous positive hardware-decoder record. The session acceptance
# check uses this message together with Moonlight's stream-resolution record.
SESSION_CPP=/src/app/streaming/session.cpp
[[ "$(grep -Fc '"FFmpeg-based video decoder chosen"' "$SESSION_CPP")" -eq 1 ]] || {
  echo "Pinned Moonlight decoder log statement changed" >&2
  exit 1
}
sed -i 's/"FFmpeg-based video decoder chosen"/"FFmpeg-based %s video decoder chosen", chosenDecoder->isHardwareAccelerated() ? "hardware-accelerated" : "software"/' "$SESSION_CPP"
[[ "$(grep -Fc '"FFmpeg-based %s video decoder chosen"' "$SESSION_CPP")" -eq 1 ]] || {
  echo "Moonlight hardware-decoder evidence patch was not applied exactly once" >&2
  exit 1
}

# The top-level project is TEMPLATE=subdirs, so command-line qmake variables are
# not a sufficiently strong guarantee for the nested application target. Put
# the media RUNPATH directly into the pinned app project before generation.
APP_PRO=/src/app/app.pro
! grep -Fq '# OPI_DEDICATED_MEDIA_RUNPATH' "$APP_PRO" || {
  echo "Unexpected pre-existing Orange Pi Moonlight qmake patch" >&2
  exit 1
}
cat >> "$APP_PRO" <<'QMAKE'

# OPI_DEDICATED_MEDIA_RUNPATH
unix:!macx {
    QMAKE_RPATHDIR += /opt/opi/media/lib
    QMAKE_LFLAGS += -Wl,-rpath,/opt/opi/media/lib
}
QMAKE
[[ "$(grep -Fc '# OPI_DEDICATED_MEDIA_RUNPATH' "$APP_PRO")" -eq 1 ]] || {
  echo "Moonlight application RUNPATH patch was not applied exactly once" >&2
  exit 1
}

qmake6 moonlight-qt.pro
make -j"$JOBS" release
[[ -x app/moonlight ]] || { echo "Moonlight build did not produce app/moonlight" >&2; exit 1; }
readelf -d app/moonlight | grep -E '(RPATH|RUNPATH).*\/opt\/opi\/media\/lib' >/dev/null || {
  echo "Moonlight binary lacks the dedicated media RUNPATH" >&2
  readelf -d app/moonlight >&2
  exit 1
}
ldd app/moonlight > /tmp/moonlight-ldd.txt
! grep -q 'not found' /tmp/moonlight-ldd.txt || {
  cat /tmp/moonlight-ldd.txt >&2
  echo "Moonlight has unresolved shared libraries" >&2
  exit 1
}
for lib in libavcodec libavutil libswscale; do
  grep -Eq "${lib}\\.so[^ ]*[[:space:]]+=>[[:space:]]+/opt/opi/media/lib/" /tmp/moonlight-ldd.txt || {
    cat /tmp/moonlight-ldd.txt >&2
    echo "Moonlight is not linked to project $lib" >&2
    exit 1
  }
done
grep -aFq 'FFmpeg-based %s video decoder chosen' app/moonlight || {
  echo "Moonlight binary lacks hardware-decoder evidence logging" >&2
  exit 1
}

install -Dm755 app/moonlight /out/rootfs/opt/opi/apps/moonlight/moonlight-qt
install -d -m0755 /out/rootfs/usr/local/bin
cat > /out/rootfs/usr/local/bin/moonlight-qt <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail
export LD_LIBRARY_PATH="/opt/opi/media/lib:${LD_LIBRARY_PATH:-}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
mkdir -p "$HOME/.local/state/opi"
if [[ -x /usr/local/bin/opi-moonlight-display-auto ]]; then
  /usr/local/bin/opi-moonlight-display-auto || echo "WARN: Moonlight display auto-detection failed; retaining safe configuration" >&2
fi
exec /opt/opi/apps/moonlight/moonlight-qt "$@" \
  2> >(tee -a "$HOME/.local/state/opi/moonlight.log" >&2)
WRAPPER
chmod 0755 /out/rootfs/usr/local/bin/moonlight-qt
bash -n /out/rootfs/usr/local/bin/moonlight-qt
[[ -x /out/rootfs/usr/local/bin/moonlight-qt ]] || {
  echo "Moonlight launcher was not packaged as an executable" >&2
  exit 1
}
grep -Fq 'exec /opt/opi/apps/moonlight/moonlight-qt "$@"' \
  /out/rootfs/usr/local/bin/moonlight-qt || {
  echo "Moonlight launcher does not execute the packaged application" >&2
  exit 1
}
mkdir -p /out/rootfs/usr/local/share/moonlight
[[ -f app/SDL_GameControllerDB/gamecontrollerdb.txt ]] &&
  cp -a app/SDL_GameControllerDB/gamecontrollerdb.txt \
    /out/rootfs/usr/local/share/moonlight/gamecontrollerdb.txt || true
assert_aarch64_tree /out/rootfs/opt/opi/apps/moonlight
collect_runtime_packages /out/rootfs/opt/opi/apps/moonlight /out/runtime-packages.txt
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
