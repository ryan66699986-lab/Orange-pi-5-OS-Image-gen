#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare

apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git clang \
  libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev libvulkan-dev \
  libsdl2-dev libsdl2-ttf-dev libfontconfig1-dev \
  libcurl4-openssl-dev libglew-dev libx11-dev libxi-dev \
  libxrandr-dev libxinerama-dev libxcursor-dev libudev-dev

git init /src
git -C /src remote add origin https://github.com/hrydgard/ppsspp.git
git_net -C /src fetch --depth=1 origin "$PPSSPP_COMMIT"
git -C /src checkout --detach FETCH_HEAD
git_net -C /src submodule update --init --recursive --depth=1
[[ "$(git -C /src rev-parse HEAD)" == "$PPSSPP_COMMIT" ]] || { echo "PPSSPP checkout does not match source lock" >&2; exit 1; }

cmake -S /src -B /src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_SYSTEM_LIBPNG=OFF \
  -DUSE_SYSTEM_FFMPEG=OFF

cmake --build /src/build --target PPSSPPSDL --parallel "$JOBS"

BIN=/src/build/PPSSPPSDL
[[ -x "$BIN" ]] || { echo "PPSSPP build completed but PPSSPPSDL was not produced" >&2; exit 1; }
install -d /out/rootfs/opt/opi/apps/ppsspp
install -m755 "$BIN" /out/rootfs/opt/opi/apps/ppsspp/PPSSPPSDL
[[ -d /src/build/assets ]] || { echo "PPSSPP build/assets directory is missing" >&2; exit 1; }
cp -a /src/build/assets /out/rootfs/opt/opi/apps/ppsspp/assets
install -d /out/rootfs/usr/local/bin
cat > /out/rootfs/usr/local/bin/ppsspp <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/opi/apps/ppsspp
exec ./PPSSPPSDL "$@"
WRAPPER
chmod 0755 /out/rootfs/usr/local/bin/ppsspp
assert_aarch64_tree /out/rootfs/opt/opi/apps/ppsspp
collect_runtime_packages /out/rootfs/opt/opi/apps/ppsspp /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
