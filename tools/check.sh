#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/orangepi5pro-gaming"

bash -n "$ROOT/build.sh"
bash -n "$PROFILE/profile.env"

for f in "$PROFILE"/stages/*.sh "$PROFILE"/recipes/*.sh; do
  bash -n "$f"
done

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat "$PROFILE"/rootfs/customize.d/*.sh.inc > "$tmp"
bash -n "$tmp"

grep -q '^CONFIG_VIDEO_ROCKCHIP_VDEC=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_DRM_PANTHOR=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_INPUT_UINPUT=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_BRCMFMAC_SDIO=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_BT_HCIUART_BCM=y$' "$PROFILE/kernel/edge-overrides.conf"

grep -q '^epiphany-browser$' "$PROFILE/packages/base.txt"
! grep -Eq '(^|/)(retroarch|libretro|lightdm|xfce)' "$PROFILE/packages/base.txt"

grep -Eq '^gamepad\|build-essential( |$)' "$PROFILE/packages/build-groups.txt"
grep -q 'command -v gcc' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -q 'gcc --version' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -q 'go env CGO_ENABLED' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -Fq -- '-DCMAKE_POLICY_VERSION_MINIMUM=3.5' "$PROFILE/recipes/build-snes9x.sh"
grep -q 'PI_PASS </dev/tty' "$PROFILE/stages/11-password.sh"
grep -q 'PI_PASS2 </dev/tty' "$PROFILE/stages/11-password.sh"

grep -Fq 'PROFILE_VERSION="$(<"${REPO_ROOT}/VERSION")"' "$PROFILE/profile.env"
grep -Fq "WORK=\"\${HOME}/opi5pro-v\${PROFILE_VERSION}-work\"" "$PROFILE/profile.env"
grep -Fq "IMAGE_BASENAME=\"OPi-Gaming-OS-v\${PROFILE_VERSION}-" "$PROFILE/profile.env"
grep -Fq -- '--arg builder "v${PROFILE_VERSION}-repo"' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq 'builder:$builder' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq "bash -seu <<'OFFLINE_QA'" "$PROFILE/stages/51-offline-image-qa.sh"
grep -qx 'OFFLINE_QA' "$PROFILE/stages/51-offline-image-qa.sh"
! grep -En 'builder:"v[0-9]+\.[0-9]+-repo"|opi5pro-v[0-9]+\.[0-9]+-work|failed-v[0-9]+\.[0-9]+' "$PROFILE/profile.env" "$PROFILE"/stages/*.sh

echo "Static repository checks: PASS"
