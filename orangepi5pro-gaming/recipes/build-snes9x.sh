#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git gettext \
  libsdl2-dev libgtkmm-3.0-dev libgtk-3-dev libminizip-dev \
  portaudio19-dev glslang-dev libpulse-dev libasound2-dev \
  libxv-dev libxinerama-dev libwayland-dev
git init /src
git -C /src remote add origin https://github.com/snes9xgit/snes9x.git
git_net -C /src fetch --depth=1 origin "$SNES9X_COMMIT"
git -C /src checkout --detach FETCH_HEAD
git_net -C /src submodule update --init --recursive --depth=1
[[ "$(git -C /src rev-parse HEAD)" == "$SNES9X_COMMIT" ]] || {
  echo "Snes9x checkout does not match the resolved commit" >&2
  exit 1
}

# Snes9x 1.63 pins glslang 9c7fd1a, whose SpvBuilder.h uses uint32_t
# without directly including <cstdint>. GCC 15 no longer supplies that type
# through a transitive include, so apply the minimal upstream-compatible fix.
SPV_BUILDER=/src/external/glslang/SPIRV/SpvBuilder.h
[[ -f "$SPV_BUILDER" ]] || {
  echo "Pinned Snes9x glslang SpvBuilder.h is missing" >&2
  exit 1
}
grep -Fqx '#include <algorithm>' "$SPV_BUILDER" || {
  echo "Pinned glslang header layout changed; refusing an unreviewed patch" >&2
  exit 1
}
if ! grep -Fqx '#include <cstdint>' "$SPV_BUILDER"; then
  sed -i '/^#include <algorithm>$/i #include <cstdint>' "$SPV_BUILDER"
fi
[[ "$(grep -Fxc '#include <cstdint>' "$SPV_BUILDER")" -eq 1 ]] || {
  echo "glslang cstdint compatibility patch was not applied exactly once" >&2
  exit 1
}

# Compile the affected translation unit first. This makes any remaining GCC 15
# incompatibility fail within minutes, before the complete Snes9x build.
printf '#include "SPIRV/SpvBuilder.h"\nint main() { return 0; }\n' |
  c++ -std=c++17 -fsyntax-only -x c++ -I/src/external/glslang -
cmake -S /src/gtk -B /src/gtk/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build /src/gtk/build --parallel "$JOBS"
DESTDIR=/out/rootfs cmake --install /src/gtk/build
if ! find /out/rootfs/usr/local -type f \( -name snes9x-gtk -o -name snes9x \) -perm -u+x -print -quit 2>/dev/null | grep -q .; then
  BIN="$(find /src/gtk/build -type f \( -name snes9x-gtk -o -name snes9x \) -perm -u+x -print -quit)"
  [[ -n "$BIN" ]] || { echo "Snes9x GTK frontend executable not found after build" >&2; exit 1; }
  install -Dm755 "$BIN" /out/rootfs/usr/local/bin/snes9x-gtk
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
git -C /src rev-parse HEAD > /out/source.commit
