#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare
apt-get install -y --no-install-recommends \
  golang-go libsdl3-dev libsdl3-ttf-dev libx11-dev \
  libwayland-dev wayland-protocols fontconfig unzip
git clone https://github.com/0x90shell/gamepad-osk.git /src
git -C /src checkout "$GAMEPAD_OSK_COMMIT"
cd /src
export CGO_ENABLED=1
go env CGO_ENABLED
go build -trimpath -ldflags='-s -w' -o gamepad-osk .
[[ -x gamepad-osk ]] || { echo "gamepad-osk build did not produce an executable" >&2; exit 1; }
install -Dm755 gamepad-osk /out/rootfs/usr/local/bin/gamepad-osk
[[ -f config.example ]] && install -Dm644 config.example /out/rootfs/usr/share/gamepad-osk/config || true
[[ -f gamepad-osk.service ]] && install -Dm644 gamepad-osk.service /out/rootfs/usr/lib/systemd/user/gamepad-osk.service || true
[[ -f gamepad-osk.udev ]] && install -Dm644 gamepad-osk.udev /out/rootfs/usr/lib/udev/rules.d/80-gamepad-osk.rules || true
DESC="$(file -b /out/rootfs/usr/local/bin/gamepad-osk)"
grep -Eqi 'ELF .*ARM aarch64|ELF .*aarch64' <<<"$DESC" || { echo "gamepad-osk is not AArch64: $DESC" >&2; exit 1; }
mkdir -p /out/rootfs/usr/local/share/fonts
if curl --retry 3 --retry-delay 2 --retry-all-errors -fL https://codeberg.org/shinmera/promptfont/releases/download/v1.14/promptfont.zip -o /tmp/promptfont.zip; then
  unzip -j /tmp/promptfont.zip promptfont.ttf -d /out/rootfs/usr/local/share/fonts || echo "WARN: promptfont archive downloaded but promptfont.ttf was not usable; text key labels will be used" >&2
else
  echo "WARN: promptfont download unavailable; gamepad-osk will use text key labels" >&2
fi
assert_aarch64_tree /out/rootfs
collect_runtime_packages /out/rootfs /out/runtime-packages.txt
