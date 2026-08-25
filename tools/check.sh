#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/orangepi5pro-gaming"

[[ -x "$ROOT/build.sh" ]]
[[ -x "$ROOT/tools/check.sh" ]]

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

# Validate the programs and structured configuration embedded inside the
# customization and artifact-recipe heredocs. `bash -n` validates only the
# outer generators; without this pass, a generated runtime helper can remain
# syntactically broken until an artifact or the final rootfs gate hours later.
# For recipe writes into /out/rootfs, also prove the literal parent directory
# is explicitly created before redirection: shell redirection cannot create it.
python3 - "$PROFILE" <<'PY'
import json
import re
import subprocess
import sys
import tomllib
import xml.etree.ElementTree as ET
from pathlib import Path

profile = Path(sys.argv[1])
start = re.compile(r"\bcat\s+>\s+(\"[^\"]+\"|'[^']+'|\S+)\s+<<'([^']+)'")
checked = 0
sources = sorted((profile / 'rootfs/customize.d').glob('*.sh.inc'))
sources += sorted((profile / 'recipes').glob('*.sh'))
for source in sources:
    lines = source.read_text(encoding='utf-8').splitlines()
    i = 0
    while i < len(lines):
        match = start.search(lines[i])
        if not match:
            i += 1
            continue
        target = match.group(1).strip('"\'')
        terminator = match.group(2)
        if source.parent.name == 'recipes' and target.startswith('/out/rootfs/'):
            parent = str(Path(target).parent)
            prefix = '\n'.join(lines[:i])
            explicit_parent = re.compile(
                r'(?:install\s+-d(?:\s+-m[0-7]+)?|mkdir\s+-p)'
                r'(?:[^\n]*\\\n)*[^\n]*' + re.escape(parent)
            )
            if not explicit_parent.search(prefix):
                raise SystemExit(
                    f'{source}: redirects to {target} before explicitly '
                    f'creating {parent}'
                )
        body = []
        i += 1
        while i < len(lines) and lines[i] != terminator:
            body.append(lines[i])
            i += 1
        if i == len(lines):
            raise SystemExit(f'{source}: unterminated heredoc for {target}')
        payload = '\n'.join(body) + '\n'
        is_shell = (
            target.endswith('.sh') or '/bin/' in target or
            '/sbin/' in target or '/libexec/' in target
        )
        if is_shell:
            result = subprocess.run(
                ['bash', '-n'], input=payload, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            if result.returncode:
                raise SystemExit(f'{source}: generated shell {target}:\n{result.stderr}')
            checked += 1
        elif target.endswith(('.json', '.jsonc')):
            json.loads(payload)
            checked += 1
        elif target.endswith('.xml'):
            ET.fromstring(payload)
            checked += 1
        elif target.endswith('.toml'):
            tomllib.loads(payload)
            checked += 1
        i += 1
if checked < 40:
    raise SystemExit(f'Only {checked} generated shell/config payloads were validated')
print(f'Generated payload checks: PASS ({checked} files)')
PY

grep -q '^CONFIG_VIDEO_ROCKCHIP_VDEC=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_DRM_PANTHOR=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_INPUT_UINPUT=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_BRCMFMAC_SDIO=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_BT_HCIUART_BCM=y$' "$PROFILE/kernel/edge-overrides.conf"
for spec in SOUND:m SND:m SND_SOC:m SND_SOC_HDMI_CODEC:m SND_SOC_ROCKCHIP_I2S_TDM:m SND_SIMPLE_CARD:m; do
  sym="${spec%%:*}"
  val="${spec#*:}"
  grep -qx "CONFIG_${sym}=${val}" "$PROFILE/kernel/edge-overrides.conf"
done

grep -q '^epiphany-browser$' "$PROFILE/packages/base.txt"
grep -q '^nvme-cli$' "$PROFILE/packages/base.txt"
grep -q '^libspa-0.2-bluetooth$' "$PROFILE/packages/base.txt"
grep -q '^pipewire-pulse$' "$PROFILE/packages/base.txt"
! grep -Eq '(^|/)(retroarch|libretro|lightdm|xfce)' "$PROFILE/packages/base.txt"

grep -Eq '^gamepad\|build-essential( |$)' "$PROFILE/packages/build-groups.txt"
grep -q 'command -v gcc' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -q 'gcc --version' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -q 'go env CGO_ENABLED' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -Fq -- '-DCMAKE_POLICY_VERSION_MINIMUM=3.5' "$PROFILE/recipes/build-snes9x.sh"
grep -Fq 'git_net -C /src fetch --depth=1 origin "$SNES9X_COMMIT"' "$PROFILE/recipes/build-snes9x.sh"
grep -Fq "sed -i '/^#include <algorithm>\$/i #include <cstdint>'" "$PROFILE/recipes/build-snes9x.sh"
grep -Fq 'c++ -std=c++17 -fsyntax-only' "$PROFILE/recipes/build-snes9x.sh"
grep -Fq -- '--enable-version3' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq -- '--libdir=lib' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'pkg-config --variable=libdir mpv' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'export LIBRARY_PATH="$MPV_LIBDIR:${LIBRARY_PATH:-}"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'git_net -C /ffmpeg fetch --depth=1 origin "$V4L2_FFMPEG_COMMIT"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'git_net -C /mpv fetch --depth=1 origin "$MPV_COMMIT"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'git_net -C /stremio fetch --depth=1 origin "$STREMIO_COMMIT"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'init.set_property("hwdec", "v4l2request-copy")?;' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'init.set_property("hwdec-codecs", "all")?;' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq "grep -aFq 'v4l2request-copy' \"\$STREMIO_BIN\"" "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'export RUST_LOG="${RUST_LOG:-warn,vd=debug}"' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq '"snes9x:build-snes9x.sh" "stremio-native:build-stremio-native.sh"' "$PROFILE/stages/31-native-artifacts.sh"
grep -Fq 'hevc-main10-hwprobe.mp4' "$PROFILE/stages/40-rootfs-assembly.sh"
grep -Fq 'Main 10' "$PROFILE/stages/40-rootfs-assembly.sh"
for probe in h264-4k-hwprobe.mp4 hevc-main10-4k-hdr10-hwprobe.mp4 vp9-4k-hwprobe.webm av1-4k-hwprobe.mkv; do
  grep -Fq "$probe" "$PROFILE/stages/40-rootfs-assembly.sh"
  grep -Fq "$probe" "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
  grep -Fq "$probe" "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
  grep -Fq "$probe" "$PROFILE/stages/51-offline-image-qa.sh"
done
grep -Fq 'opi-stremio-session-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-moonlight-hwcheck' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-moonlight-session-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-controller-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'EasySMX|X20|Xbox|X-Box|gamepad|joystick' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-audio-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-nvme-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'Read-only NVMe inventory' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'udiskie --automount --no-notify' "$PROFILE/rootfs/customize.d/30-controller-session.sh.inc"
! grep -Eqi 'lumera|android.*(container|apk)|waydroid' "$PROFILE/packages/base.txt" "$PROFILE/packages/build-groups.txt" "$PROFILE/sources.env" "$PROFILE"/recipes/*.sh
! grep -F 'cmake --install' "$PROFILE"/recipes/*.sh | grep -Fq '|| true'
grep -Fq 'for cmd in es-de rmg flycast melonds azahar snes9x-gtk' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'stremio_linux_shell_commit:$stremio_commit' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq 'mpv_commit:$mpv_commit' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq 'moonlight_commit:$moonlight_commit' "$PROFILE/stages/13-source-resolution.sh"
grep -Fq 'STREMIO_COMMIT=$STREMIO_COMMIT' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'MPV_COMMIT=$MPV_COMMIT' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'MOONLIGHT_COMMIT=$MOONLIGHT_COMMIT' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'git_net -C /src fetch --depth=1 origin "$MOONLIGHT_COMMIT"' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq '/opt/opi/media/lib/pkgconfig' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'FFmpeg-based %s video decoder chosen' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'chosenDecoder->isHardwareAccelerated()' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'QMAKE_RPATHDIR += /opt/opi/media/lib' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'RPATH|RUNPATH' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'install -d -m0755 /out/rootfs/usr/local/bin' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'bash -n /out/rootfs/usr/local/bin/moonlight-qt' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'Moonlight launcher was not packaged as an executable' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'Built Moonlight commit differs from source lock' "$PROFILE/stages/31-native-artifacts.sh"
for component in PPSSPP RMG Flycast melonDS Azahar; do
  grep -Fq "Built ${component} commit differs from source lock" "$PROFILE/stages/31-native-artifacts.sh"
done
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
grep -Fq '/usr/bin/armbian-install' "$PROFILE/stages/51-offline-image-qa.sh"
! grep -Fq '/usr/sbin/armbian-install' "$PROFILE/stages/51-offline-image-qa.sh"
for unit in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  grep -Fq "$unit" "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
  grep -Fq "$unit" "$PROFILE/stages/51-offline-image-qa.sh"
done
grep -Fq 'branches: [main]' "$ROOT/.github/workflows/ci.yml"
grep -qx '3.16' "$ROOT/VERSION"
! grep -En 'builder:"v[0-9]+\.[0-9]+-repo"|opi5pro-v[0-9]+\.[0-9]+-work|failed-v[0-9]+\.[0-9]+' "$PROFILE/profile.env" "$PROFILE"/stages/*.sh
grep -Fq 'timeout --kill-after=30s' "$PROFILE/stages/00-common.sh"
grep -Fq 'timeout --kill-after=30s' "$PROFILE/recipes/arm64-common.sh"
! grep -ERn --include='*.sh' '^[[:space:]]*git[[:space:]]+(clone|fetch|ls-remote)' "$PROFILE/stages" "$PROFILE/recipes"

# Until image finalization, the repository may inventory/SMART-check NVMe but
# must never partition, format, mount, migrate to, or write the installed NVMe.
! grep -ERni --include='*.sh' --include='*.inc' '(mkfs([.]|[[:space:]])|wipefs|sfdisk|parted|nvme[[:space:]]+format)' "$PROFILE"
awk '/cat > \/usr\/local\/bin\/opi-nvme-check /{copy=1; next} copy && /^EOF$/{exit} copy{print}' \
  "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc" > "$tmpdir/opi-nvme-check"
[[ -s "$tmpdir/opi-nvme-check" ]]
bash -n "$tmpdir/opi-nvme-check"
grep -Fq 'nvme smart-log "$dev"' "$tmpdir/opi-nvme-check"
! grep -Eqi '(^|[^[:alnum:]_])(mount|umount|mkfs|wipefs|fdisk|sfdisk|parted|dd)([^[:alnum:]_]|$)' "$tmpdir/opi-nvme-check"

echo "Static repository checks: PASS"
