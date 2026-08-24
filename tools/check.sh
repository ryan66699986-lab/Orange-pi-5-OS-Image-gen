#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/orangepi5pro-gaming"

bash -n "$ROOT/build.sh"
bash -n "$PROFILE/profile.env"

for f in "$PROFILE"/stages/*.sh "$PROFILE"/recipes/*.sh; do
  bash -n "$f"
done

tmpdir="$(mktemp -d)"
trap 'rm -rf -- "$tmpdir"' EXIT
cat "$PROFILE"/rootfs/customize.d/*.sh.inc > "$tmpdir/customize-image.sh"
bash -n "$tmpdir/customize-image.sh"
awk '/<<'\''OFFLINE_QA'\''/{copy=1; next} copy && /^OFFLINE_QA$/{exit} copy{print}' \
  "$PROFILE/stages/51-offline-image-qa.sh" > "$tmpdir/offline-image-qa.sh"
[[ -s "$tmpdir/offline-image-qa.sh" ]]
bash -n "$tmpdir/offline-image-qa.sh"

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
grep -Fq -- '--enable-version3' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'git -C /ffmpeg fetch --depth=1 origin "$V4L2_FFMPEG_COMMIT"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'git -C /mpv fetch --depth=1 origin "$MPV_COMMIT"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'git -C /stremio fetch --depth=1 origin "$STREMIO_COMMIT"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'init.set_property("hwdec", "v4l2request-copy")?;' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'init.set_property("hwdec-codecs", "all")?;' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq "grep -aFq 'v4l2request-copy' \"\$STREMIO_BIN\"" "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'export RUST_LOG="${RUST_LOG:-warn,vd=debug}"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq '"stremio-native:build-stremio-native.sh" "snes9x:build-snes9x.sh"' "$PROFILE/stages/31-native-artifacts.sh"
grep -Fq 'hevc-main10-hwprobe.mp4' "$PROFILE/stages/40-rootfs-assembly.sh"
grep -Fq 'Main 10' "$PROFILE/stages/40-rootfs-assembly.sh"
grep -Fq 'opi-stremio-session-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'udiskie --automount --no-notify' "$PROFILE/rootfs/customize.d/30-controller-session.sh.inc"
! grep -Eqi 'lumera|android.*(container|apk)|waydroid' "$PROFILE/packages/base.txt" "$PROFILE/packages/build-groups.txt" "$PROFILE/sources.env" "$PROFILE"/recipes/*.sh
! grep -F 'cmake --install' "$PROFILE"/recipes/*.sh | grep -Fq '|| true'
grep -Fq 'for cmd in es-de rmg flycast melonds azahar snes9x-gtk' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'stremio_linux_shell_commit:$stremio_commit' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq 'mpv_commit:$mpv_commit' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq 'STREMIO_COMMIT=$STREMIO_COMMIT' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'MPV_COMMIT=$MPV_COMMIT' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq '.components[$key]=$commit' "$PROFILE/stages/31-native-artifacts.sh"
grep -Fq '.artifact_sha256[$name]=$hash' "$PROFILE/stages/32-steam-and-merge.sh"
grep -q 'PI_PASS </dev/tty' "$PROFILE/stages/11-password.sh"
grep -q 'PI_PASS2 </dev/tty' "$PROFILE/stages/11-password.sh"

grep -Fq 'PROFILE_VERSION="$(<"${REPO_ROOT}/VERSION")"' "$PROFILE/profile.env"
grep -Fq "WORK=\"\${HOME}/opi5pro-v\${PROFILE_VERSION}-work\"" "$PROFILE/profile.env"
grep -Fq "IMAGE_BASENAME=\"OPi-Gaming-OS-v\${PROFILE_VERSION}-" "$PROFILE/profile.env"
grep -Fq -- '--arg builder "v${PROFILE_VERSION}-repo"' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq 'builder:$builder' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq "bash -seu <<'OFFLINE_QA'" "$PROFILE/stages/51-offline-image-qa.sh"
grep -qx 'OFFLINE_QA' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq 'branches: [main]' "$ROOT/.github/workflows/ci.yml"
grep -qx '3.13' "$ROOT/VERSION"
! grep -En 'builder:"v[0-9]+\.[0-9]+-repo"|opi5pro-v[0-9]+\.[0-9]+-work|failed-v[0-9]+\.[0-9]+' "$PROFILE/profile.env" "$PROFILE"/stages/*.sh

echo "Static repository checks: PASS"
