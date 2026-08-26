#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh

export DEBIAN_FRONTEND=noninteractive
if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
    sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' \
        /etc/apt/sources.list.d/ubuntu.sources
fi
apt-get update
apt-get install -y --no-install-recommends squashfs-tools file python3 ca-certificates

APP=/input/app.AppImage
DEST=/out/rootfs/opt/opi/apps/"$APPNAME"

[[ -s "$APP" ]] || { echo "Missing/empty AppImage: $APP" >&2; exit 1; }

DESC="$(file -b "$APP")"
grep -Eqi 'ELF .*ARM aarch64|ELF .*aarch64' <<<"$DESC" || {
    echo "Expected AArch64 AppImage runtime but got: $DESC" >&2
    exit 1
}

mapfile -t CANDIDATES < <(
python3 - "$APP" <<'PY'
import mmap, sys
with open(sys.argv[1], "rb") as f:
    mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    pos = 0
    while True:
        pos = mm.find(b"hsqs", pos)
        if pos < 0:
            break
        print(pos)
        pos += 1
    mm.close()
PY
)

((${#CANDIDATES[@]})) || { echo "No SquashFS magic in AppImage" >&2; exit 1; }

OFFSET=""
for candidate in "${CANDIDATES[@]}"; do
    if unsquashfs -s -o "$candidate" "$APP" >/dev/null 2>&1; then
        OFFSET="$candidate"
        break
    fi
done

[[ -n "$OFFSET" ]] || { echo "No valid embedded SquashFS filesystem" >&2; exit 1; }

rm -rf -- "$DEST"
mkdir -p "$(dirname "$DEST")"
unsquashfs -no-progress -o "$OFFSET" -d "$DEST" "$APP" >/dev/null

[[ -x "$DEST/AppRun" ]] || { echo "Extracted AppImage has no executable AppRun" >&2; exit 1; }
assert_aarch64_tree "$DEST"
: > /out/runtime-packages.txt
printf '%s\n' "$OFFSET" > /out/appimage-squashfs-offset.txt
