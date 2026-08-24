#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

log(){ printf '\n[OPI V3.10] %s\n' "$*"; }

[[ -d /tmp/overlay ]] || { echo "Armbian overlay missing" >&2; exit 1; }
install -d -m0755 /opt/opi-build-meta /opt/opi /usr/local/libexec/opi-emulators

log "Enable Ubuntu components"
if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
    sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' \
        /etc/apt/sources.list.d/ubuntu.sources
fi
apt-get update

log "Install preflighted Resolute ARM64 runtime"
mapfile -t REQUIRED < /tmp/overlay/opt/opi-build-meta/required-packages.txt
apt-get install -y --no-install-recommends "${REQUIRED[@]}"

log "Browser: Ubuntu-native Epiphany/Web"
command -v epiphany >/dev/null 2>&1 || {
    echo "Epiphany browser missing after runtime package install" >&2
    exit 1
}

log "Copy prebuilt validated overlay"
cp -a /tmp/overlay/. /

log "Create local user"
PASS_HASH="$(cat /opt/opi-build-meta/user-password.hash)"
for g in sudo audio video render input plugdev bluetooth; do
    getent group "$g" >/dev/null 2>&1 || groupadd --system "$g"
done
if ! id ryan >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,render,input,plugdev,bluetooth ryan
fi
usermod -aG sudo,audio,video,render,input,plugdev,bluetooth ryan
usermod -p "$PASS_HASH" ryan
rm -f /opt/opi-build-meta/user-password.hash

log "Input/controller kernel modules"
install -d -m0755 /etc/modules-load.d
cat > /etc/modules-load.d/opi-gaming.conf <<'EOF'
zram
uinput
uhid
EOF
cat > /etc/sudoers.d/90-opi-gaming <<'EOF'
ryan ALL=(root) NOPASSWD: /usr/local/sbin/opi-set-session, /usr/bin/systemctl restart greetd, /usr/bin/systemctl reboot, /usr/bin/systemctl poweroff
EOF
chmod 0440 /etc/sudoers.d/90-opi-gaming

log "Normalize distro emulator command paths"
normalize_command() {
    local name="$1"; shift
    command -v "$name" >/dev/null 2>&1 && return 0
    local candidate
    for candidate in "$@"; do
        if [[ -x "$candidate" ]]; then
            ln -sf "$candidate" "/usr/local/bin/$name"
            return 0
        fi
    done
    return 1
}
normalize_command gamescope /usr/bin/gamescope /usr/games/gamescope || true
normalize_command dolphin-emu /usr/bin/dolphin-emu /usr/games/dolphin-emu || true
normalize_command sameboy /usr/bin/sameboy /usr/games/sameboy || true
normalize_command mgba-qt /usr/bin/mgba-qt /usr/games/mgba-qt || true
normalize_command nestopia /usr/bin/nestopia /usr/games/nestopia || true

log "Expose standalone AppImage emulators"
ln -sf /opt/opi/apps/duckstation/AppRun /usr/local/bin/duckstation
ln -sf /opt/opi/apps/armsx2/AppRun /usr/local/bin/armsx2
test -x /usr/local/bin/ppsspp || { echo "Native PPSSPP wrapper missing" >&2; exit 1; }
if ! command -v rmg >/dev/null 2>&1; then
    RMG_BIN="$(find /usr/local -type f \( -name RMG -o -name rmg \) -perm -u+x | head -n1 || true)"
    [[ -n "$RMG_BIN" ]] && ln -sf "$RMG_BIN" /usr/local/bin/rmg
fi
if ! command -v melonds >/dev/null 2>&1; then
    MELON_BIN="$(find /usr/local -type f -iname 'melonDS' -perm -u+x | head -n1 || true)"
    [[ -n "$MELON_BIN" ]] && ln -sf "$MELON_BIN" /usr/local/bin/melonds
fi
if ! command -v snes9x-gtk >/dev/null 2>&1; then
    SNES_BIN="$(find /usr/local -type f \( -name snes9x-gtk -o -name snes9x \) -perm -u+x | head -n1 || true)"
    [[ -n "$SNES_BIN" ]] && ln -sf "$SNES_BIN" /usr/local/bin/snes9x-gtk
fi
if ! command -v flycast >/dev/null 2>&1; then
    FLYCAST_BIN="$(find /usr/local -type f -name flycast -perm -u+x | head -n1 || true)"
    [[ -n "$FLYCAST_BIN" ]] && ln -sf "$FLYCAST_BIN" /usr/local/bin/flycast
fi
if ! command -v azahar >/dev/null 2>&1; then
    AZAHAR_BIN="$(find /usr/local -type f \( -name azahar -o -name azahar-qt -o -name citra-qt \) -perm -u+x | head -n1 || true)"
    [[ -n "$AZAHAR_BIN" ]] && ln -sf "$AZAHAR_BIN" /usr/local/bin/azahar
fi
