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
awk '/<<'\''RUNTIME_CLOSURE'\''/{copy=1; next} copy && /^RUNTIME_CLOSURE$/{exit} copy{print}' \
  "$PROFILE/stages/33-runtime-closure.sh" > "$tmpdir/runtime-closure.sh"
[[ -s "$tmpdir/runtime-closure.sh" ]]
bash -n "$tmpdir/runtime-closure.sh"
awk '/<<'\''BUILDER_DEPS'\''/{copy=1; next} copy && /^BUILDER_DEPS$/{copy=0; next} copy{print}' \
  "$PROFILE/stages/18-builder-dependency-cache.sh" > "$tmpdir/builder-dependency-cache.sh"
[[ -s "$tmpdir/builder-dependency-cache.sh" ]]
bash -n "$tmpdir/builder-dependency-cache.sh"
echo "Builder dependency container shell checks: PASS"

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

# Validate shell programs embedded as single-quoted `bash -ceu` container
# payloads. Outer-script `bash -n` cannot see syntax errors inside the string.
python3 - "$PROFILE" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

profile = Path(sys.argv[1])
pattern = re.compile(r"bash -ceu '\n(.*?)\n'\)\"", re.DOTALL)
checked = 0
for source in sorted((profile / "stages").glob("*.sh")):
    text = source.read_text(encoding="utf-8")
    for match in pattern.finditer(text):
        result = subprocess.run(
            ["bash", "-n"], input=match.group(1), text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        if result.returncode:
            raise SystemExit(
                f"{source}: embedded container shell payload:\n{result.stderr}"
            )
        checked += 1
if checked < 1:
    raise SystemExit("No embedded container shell payloads were validated")
print(f"Embedded container shell checks: PASS ({checked} payloads)")
PY

# Shell syntax does not validate embedded Python heredocs. Compile every
# literal PY payload in customization fragments, recipes and stages so a
# launch-time helper cannot hide a Python syntax failure until the device boots.
python3 - "$PROFILE" <<'PY'
import re
import sys
from pathlib import Path

profile = Path(sys.argv[1])
sources = list((profile / "rootfs/customize.d").glob("*.sh.inc"))
sources += list((profile / "recipes").glob("*.sh"))
sources += list((profile / "stages").glob("*.sh"))
pattern = re.compile(r"<<'PY'\n(.*?)\nPY$", re.MULTILINE | re.DOTALL)
checked = 0
for source in sorted(sources):
    text = source.read_text(encoding="utf-8")
    for match in pattern.finditer(text):
        compile(match.group(1), f"{source}:PY-heredoc-{checked + 1}", "exec")
        checked += 1
if checked < 3:
    raise SystemExit(f"Only {checked} embedded Python payloads were compiled")
print(f"Embedded Python checks: PASS ({checked} payloads)")
PY

grep -q '^CONFIG_VIDEO_ROCKCHIP_VDEC=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_DRM_PANTHOR=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_INPUT_UINPUT=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_BRCMFMAC_SDIO=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_BT_HCIUART_BCM=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_BTRFS_FS=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_EXFAT_FS=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_NTFS3_FS=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_VFAT_FS=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_RC_CORE=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_MEDIA_CEC_RC=y$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_F2FS_FS=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_XFS_FS=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_ISO9660_FS=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -q '^CONFIG_UDF_FS=m$' "$PROFILE/kernel/edge-overrides.conf"
grep -Fq '"RC_CORE:y" "MEDIA_CEC_RC:y"' "$PROFILE/stages/20-armbian-kernel.sh"
grep -Fq '"F2FS_FS:m" "XFS_FS:m" "ISO9660_FS:m" "UDF_FS:m"' "$PROFILE/stages/20-armbian-kernel.sh"
grep -Fq 'Btrfs root filesystem support was lost' "$PROFILE/stages/50-final-audit-build.sh"
for spec in SOUND:m SND:m SND_SOC:m SND_SOC_HDMI_CODEC:m SND_SOC_ROCKCHIP_I2S_TDM:m SND_SIMPLE_CARD:m; do
  sym="${spec%%:*}"
  val="${spec#*:}"
  grep -qx "CONFIG_${sym}=${val}" "$PROFILE/kernel/edge-overrides.conf"
done

! grep -q '^epiphany-browser$' "$PROFILE/packages/base.txt"
for pkg in btrfs-progs dosfstools e2fsprogs exfatprogs ntfs-3g f2fs-tools xfsprogs mesa-vulkan-drivers unattended-upgrades wireless-regdb iw wlr-randr edid-decode locales; do
  grep -qx "$pkg" "$PROFILE/packages/base.txt"
done
for pkg in libsdl2-ttf-2.0-0 libqt6quickcontrols2-6; do
  grep -qx "$pkg" "$PROFILE/packages/base.txt"
  grep -qx "$pkg" "$PROFILE/recipes/build-moonlight.sh"
done
for pkg in libsdl3-0 libsdl3-ttf0; do
  grep -qx "$pkg" "$PROFILE/packages/base.txt"
  grep -qx "$pkg" "$PROFILE/recipes/build-gamepad-osk.sh"
  grep -Fq "$pkg" "$PROFILE/stages/33-runtime-closure.sh"
done
grep -qx 'libglew2.2' "$PROFILE/packages/base.txt"
grep -qx 'libglew2.2' "$PROFILE/recipes/build-ppsspp.sh"
grep -Fq 'PPSSPP runtime manifest lacks libglew2.2' "$PROFILE/recipes/build-ppsspp.sh"
grep -Fq 'PPSSPP build artifact does not resolve libGLEW.so.2.2' "$PROFILE/recipes/build-ppsspp.sh"
grep -Fq 'PPSSPP does not resolve libGLEW.so.2.2 in merged runtime preflight' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'canonical="$(readlink -f "$lib"' "$PROFILE/recipes/arm64-common.sh"
grep -Fq 'dpkg-query -S "$canonical"' "$PROFILE/recipes/arm64-common.sh"
grep -Fq 'Resolved system libraries without a dpkg owner' "$PROFILE/recipes/arm64-common.sh"
grep -Fq 'RUNTIME_LIBRARY_PATH' "$PROFILE/recipes/arm64-common.sh"
grep -Fq 'Mandatory native artifact lacks a runtime package manifest' "$PROFILE/stages/32-steam-and-merge.sh"
grep -Fq 'runtime-packages.closure.txt' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'core_runtime_roots=' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'collect_runtime_packages "$root" "$derived"' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 ldd "$path"' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'find "$root" -type f' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'find "$root" -type f' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
! grep -Fq 'find "${appimage_roots[@]}" -type f' "$PROFILE/stages/33-runtime-closure.sh" "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'Generated runtime contract package missing from target rootfs' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'Final image runtime package contract: PASS' "$PROFILE/stages/51-offline-image-qa.sh"
grep -q '^nvme-cli$' "$PROFILE/packages/base.txt"
grep -q '^libspa-0.2-bluetooth$' "$PROFILE/packages/base.txt"
grep -q '^pipewire-pulse$' "$PROFILE/packages/base.txt"
! grep -Eq '(^|/)(retroarch|libretro|lightdm|xfce)' "$PROFILE/packages/base.txt"

grep -Eq '^gamepad\|build-essential( |$)' "$PROFILE/packages/build-groups.txt"
grep -Fq 'BUILDER_CACHE_SCHEMA="v1-ubuntu26.04-arm64-ccache"' "$PROFILE/stages/18-builder-dependency-cache.sh"
grep -Fq 'sha256sum "$WORK/build-package-groups.txt"' "$PROFILE/stages/18-builder-dependency-cache.sh"
grep -Fq 'org.opi5pro.builder-cache-key' "$PROFILE/stages/18-builder-dependency-cache.sh"
grep -Fq 'Cached ARM64 builder dependency is missing' "$PROFILE/stages/18-builder-dependency-cache.sh"
grep -Fq 'OPI_BUILD_DEPS_READY=1' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'CCACHE_COMPILERCHECK=content' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'CCACHE_NAMESPACE=opi5pro-${name}' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'CARGO_HOME=/tool-cache/cargo' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'GOMODCACHE=/tool-cache/go-mod' "$PROFILE/stages/21-arm64-build-helper.sh"
grep -Fq 'USE_CCACHE=yes' "$PROFILE/stages/50-final-audit-build.sh"
! grep -Eq '\$ART|artifacts|overlay-root' "$PROFILE/stages/18-builder-dependency-cache.sh"
grep -q 'command -v gcc' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -q 'gcc --version' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -q 'go env CGO_ENABLED' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -Fq 'sort -u -o /out/runtime-packages.txt' "$PROFILE/recipes/build-gamepad-osk.sh"
grep -Fq 'ARM64 merged-artifact runtime closure preflight' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'Unresolved shared library before Armbian build' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'libSDL3_ttf.so.0' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq '/opt/opi/apps/duckstation /opt/opi/apps/armsx2' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'Unresolved executable dependency in extracted AppImage' "$PROFILE/stages/33-runtime-closure.sh"
grep -Fq 'appimage_checked >= 2' "$PROFILE/stages/33-runtime-closure.sh"
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
grep -Fq 'ID_INPUT_JOYSTICK=1' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-audio-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-audio-initial-default' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'wpctl set-default' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-gpu-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'panfrost_icd.json' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'llvmpipe|lavapipe' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-cec-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'armbian-firmware' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'brcmfmac*-sdio.bin*' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq 'opi-nvme-check' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'Read-only NVMe inventory' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-validation-report' "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc"
grep -Fq 'opi-moonlight-display-auto' "$PROFILE/rootfs/customize.d/20-media-steam.sh.inc"
grep -Fq 'wlr-randr --json' "$PROFILE/rootfs/customize.d/20-media-steam.sh.inc"
grep -Fq 'HDR Static Metadata Data Block' "$PROFILE/rootfs/customize.d/20-media-steam.sh.inc"
grep -Fq 'def best_mode(display):' "$PROFILE/rootfs/customize.d/20-media-steam.sh.inc"
grep -Fq '/usr/local/bin/opi-moonlight-display-auto' "$PROFILE/recipes/build-moonlight.sh"
grep -Fq 'guide+start' "$PROFILE/rootfs/customize.d/30-controller-session.sh.inc"
grep -Fq 'ensure_gamepad_mouse_enabled()' "$PROFILE/rootfs/customize.d/30-controller-session.sh.inc"
grep -Fq 'controller mouse is not enabled' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'btrfs inspect-internal map-swapfile' "$PROFILE/rootfs/customize.d/60-performance-services.sh.inc"
grep -Fq 'Steam-Experimental.sh' "$PROFILE/rootfs/customize.d/60-performance-services.sh.inc"
grep -Fq 'Restart-Gaming-Mode.sh' "$PROFILE/rootfs/customize.d/60-performance-services.sh.inc"
grep -Fq 'XKBLAYOUT="gb"' "$PROFILE/rootfs/customize.d/60-performance-services.sh.inc"
grep -Fq 'REGDOMAIN=GB' "$PROFILE/rootfs/customize.d/60-performance-services.sh.inc"
grep -Fq '"${distro_id}:${distro_codename}-security"' "$PROFILE/rootfs/customize.d/60-performance-services.sh.inc"
grep -Fq 'brave-browser-apt-release.s3.brave.com/brave-browser.sources' "$PROFILE/stages/17-browser-preflight.sh"
grep -Fq 'https://packages.mozilla.org/apt' "$PROFILE/stages/17-browser-preflight.sh"
for fpr in DBF1A116C220B8C7164F98230686B78420038257 47D32A74E9A9E013A4B4926C68D513D36A73CD96 B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0; do
  grep -Fq "$fpr" "$PROFILE/stages/17-browser-preflight.sh"
  grep -Fq "$fpr" "$PROFILE/rootfs/customize.d/00-base-user-input.sh.inc"
done
! grep -Fq 'D16166072CACDF2C9429CBF11BF41E37D039F691' "$PROFILE/stages/17-browser-preflight.sh" "$PROFILE/rootfs/customize.d/00-base-user-input.sh.inc" "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'actual_brave_fingerprints' "$PROFILE/stages/17-browser-preflight.sh"
grep -Fq 'verify_brave_release_keyring()' "$PROFILE/rootfs/customize.d/00-base-user-input.sh.inc"
grep -Fq 'verify_brave_release_keyring /usr/share/keyrings/brave-browser-archive-keyring.gpg' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'Brave repository URI mismatch' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'Brave repository keyring binding mismatch' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq '35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3' "$PROFILE/stages/17-browser-preflight.sh"
grep -Fq 'x-scheme-handler/https=brave-browser.desktop' "$PROFILE/rootfs/customize.d/40-desktop-storage.sh.inc"
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
grep -Fq 'Mandatory application runtime package missing' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'Moonlight SDL2_ttf runtime link is missing' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'Moonlight Qt Quick Controls runtime link is missing' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq '/usr/lib/aarch64-linux-gnu/libSDL2_ttf-2.0.so.0' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq '/usr/lib/aarch64-linux-gnu/libQt6QuickControls2.so.6' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq '/usr/lib/aarch64-linux-gnu/libSDL3.so.0' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq '/usr/lib/aarch64-linux-gnu/libSDL3_ttf.so.0' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq 'gamepad-osk runtime link is missing' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq 'PPSSPP GLEW runtime link is missing' "$PROFILE/rootfs/customize.d/70-final-rootfs-gate.sh.inc"
grep -Fq '/usr/lib/aarch64-linux-gnu/libGLEW.so.2.2' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq 'libglew2.2 mesa-vulkan-drivers' "$PROFILE/stages/51-offline-image-qa.sh"
grep -Fq 'Categories=AudioVideo;Video;Player;' "$PROFILE/recipes/build-stremio-native.sh"
! grep -Fq 'Categories=Utility;AudioVideo;Video;Player;' "$PROFILE/recipes/build-stremio-native.sh"
grep -Fq 'runuser -u ryan -- env HOME=/home/ryan USER=ryan LOGNAME=ryan' "$PROFILE/rootfs/customize.d/20-media-steam.sh.inc"
! grep -Fq 'sudo -u ryan' "$PROFILE/rootfs/customize.d/20-media-steam.sh.inc"
grep -Fq 'Built Moonlight commit differs from source lock' "$PROFILE/stages/31-native-artifacts.sh"
grep -Eq '^DUCK_RELEASE_ID=[0-9]+$' "$PROFILE/sources.env"
grep -Eq '^DUCK_ARM64_SHA256=[0-9a-f]{64}$' "$PROFILE/sources.env"
grep -Fq 'pinned AppImage SHA-256 mismatch' "$PROFILE/stages/30-opencode-appimages.sh"
grep -Fq 'duckstation_sha256:$duck_sha256' "$PROFILE/stages/13-source-resolution.sh"
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
grep -qx '3.25' "$ROOT/VERSION"
grep -Fq 'CACHE_ROOT="${OPI5PRO_CACHE_ROOT:-${HOME}/.cache/opi5pro-builder}"' "$PROFILE/profile.env"
grep -Fq 'os.path.realpath' "$PROFILE/stages/01-cleanup-workspace.sh"
grep -Fq '"$REPO_ROOT"|"$REPO_ROOT"/*' "$PROFILE/stages/01-cleanup-workspace.sh"
grep -Fq 'Unsafe cache root' "$PROFILE/stages/01-cleanup-workspace.sh"
grep -Fq 'stage-timings.tsv' "$PROFILE/profile.env" "$PROFILE/stages/01-cleanup-workspace.sh"
grep -Fq 'TIMING: scope=stage' "$ROOT/build.sh"
grep -Fq 'TIMING: scope=build' "$ROOT/build.sh"
grep -Fq 'TIMING_ROWS+=("stage\t${CURRENT_STAGE_NAME}\t${status}\t${elapsed}")' "$ROOT/build.sh"
grep -Fq 'while (( TIMING_FLUSHED_COUNT < ${#TIMING_ROWS[@]} )); do' "$ROOT/build.sh"
grep -Fq 'Verified download cache hit' "$PROFILE/stages/00-common.sh"
grep -Fq 'Discarding invalid cached download' "$PROFILE/stages/00-common.sh"
! grep -Fq 'CACHE_ROOT="${WORK}' "$PROFILE/profile.env"
! grep -En 'builder:"v[0-9]+\.[0-9]+-repo"|opi5pro-v[0-9]+\.[0-9]+-work|failed-v[0-9]+\.[0-9]+' "$PROFILE/profile.env" "$PROFILE"/stages/*.sh
grep -Fq 'timeout --kill-after=30s' "$PROFILE/stages/00-common.sh"
grep -Fq 'timeout --kill-after=30s' "$PROFILE/recipes/arm64-common.sh"
! grep -ERn --include='*.sh' '^[[:space:]]*git[[:space:]]+(clone|fetch|ls-remote)' "$PROFILE/stages" "$PROFILE/recipes"

# Exercise the exact gamepad mouse normalizer against both a changed upstream
# default and a config with no mouse section. Also prove the final validator
# accepts the pinned example's legal inline-comment form.
source <(sed -n '/^ensure_gamepad_mouse_enabled()/,/^}/p' \
  "$PROFILE/rootfs/customize.d/30-controller-session.sh.inc")
cat > "$tmpdir/gamepad-mouse-existing.ini" <<'EOF'
[gamepad]
toggle_combo = guide+start

[mouse]
enabled = false             # simulate a changed upstream default
sensitivity = 10
EOF
ensure_gamepad_mouse_enabled "$tmpdir/gamepad-mouse-existing.ini"
grep -qx 'enabled = true' "$tmpdir/gamepad-mouse-existing.ini"
[[ "$(grep -Ec '^[[:space:]]*\[mouse\][[:space:]]*$' "$tmpdir/gamepad-mouse-existing.ini")" -eq 1 ]]

cat > "$tmpdir/gamepad-mouse-missing.ini" <<'EOF'
[gamepad]
toggle_combo = guide+start
EOF
ensure_gamepad_mouse_enabled "$tmpdir/gamepad-mouse-missing.ini"
grep -qx 'enabled = true' "$tmpdir/gamepad-mouse-missing.ini"
[[ "$(grep -Ec '^[[:space:]]*\[mouse\][[:space:]]*$' "$tmpdir/gamepad-mouse-missing.ini")" -eq 1 ]]
sed -i 's/^enabled = true$/enabled = true  # legal inline comment/' "$tmpdir/gamepad-mouse-missing.ini"
awk 'BEGIN{ok=0} /^[[:space:]]*\[mouse\][[:space:]]*$/{mouse=1;next} /^[[:space:]]*\[/{mouse=0} mouse && /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true([[:space:]]*#.*)?[[:space:]]*$/{ok=1} END{exit !ok}' "$tmpdir/gamepad-mouse-missing.ini"
echo "gamepad-osk config mutation/validation checks: PASS"

# Prove the generic ELF runtime collector handles the merged-/usr path form
# that caused past late failures. The first dpkg lookup intentionally fails;
# the canonical retry must retain the multiarch package owner. Also prove that
# an unowned system library now fails instead of being silently discarded.
mkdir -p "$tmpdir/runtime-owner-bin" "$tmpdir/runtime-owner-root"
touch "$tmpdir/runtime-owner-root/app" "$tmpdir/runtime-owner-root/libGLEW.so.2.2"
cat > "$tmpdir/runtime-owner-bin/file" <<'EOF'
#!/usr/bin/env bash
echo 'ELF 64-bit LSB pie executable, ARM aarch64'
EOF
cat > "$tmpdir/runtime-owner-bin/ldd" <<'EOF'
#!/usr/bin/env bash
echo "libGLEW.so.2.2 => ${RUNTIME_OWNER_FAKE_LIB:?} (0x0000)"
EOF
cat > "$tmpdir/runtime-owner-bin/readlink" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -f ]] || exit 2
echo /usr/lib/aarch64-linux-gnu/libGLEW.so.2.2.0
EOF
cat > "$tmpdir/runtime-owner-bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
[[ "${RUNTIME_OWNER_UNMAPPED:-0}" == 0 && "${*: -1}" == /usr/lib/aarch64-linux-gnu/libGLEW.so.2.2.0 ]] || exit 1
echo 'libglew2.2:arm64: /usr/lib/aarch64-linux-gnu/libGLEW.so.2.2.0'
EOF
chmod +x "$tmpdir/runtime-owner-bin"/*
(
  source "$PROFILE/recipes/arm64-common.sh"
  RUNTIME_OWNER_FAKE_LIB="$tmpdir/runtime-owner-root/libGLEW.so.2.2" \
    PATH="$tmpdir/runtime-owner-bin:$PATH" collect_runtime_packages \
    "$tmpdir/runtime-owner-root" "$tmpdir/runtime-owner-packages.txt"
)
grep -qx libglew2.2 "$tmpdir/runtime-owner-packages.txt"
if (
  source "$PROFILE/recipes/arm64-common.sh"
  RUNTIME_OWNER_UNMAPPED=1 \
    RUNTIME_OWNER_FAKE_LIB="$tmpdir/runtime-owner-root/libGLEW.so.2.2" \
    PATH="$tmpdir/runtime-owner-bin:$PATH" \
    collect_runtime_packages "$tmpdir/runtime-owner-root" \
      "$tmpdir/runtime-owner-unmapped.txt" 2>/dev/null
); then
  echo "Runtime collector accepted an unowned system library" >&2
  exit 1
fi
echo "Runtime package-owner collector checks: PASS"

# A cache hit must reuse the verified bytes, while corruption must invalidate
# the cache entry and fetch the source again. This uses a local file URL so CI
# exercises the real downloader without network access.
(
  source "$PROFILE/stages/00-common.sh"
  DOWNLOAD_CACHE="$tmpdir/download-cache"
  mkdir -p "$DOWNLOAD_CACHE"
  printf 'first-payload\n' > "$tmpdir/download-source"
  url="file://$tmpdir/download-source"
  download "$url" "$tmpdir/download-first"
  cmp "$tmpdir/download-source" "$tmpdir/download-first"
  printf 'second-payload\n' > "$tmpdir/download-source"
  download "$url" "$tmpdir/download-second"
  cmp "$tmpdir/download-first" "$tmpdir/download-second"
  key="$(printf '%s' "$url" | sha256sum | awk '{print $1}')"
  printf 'corrupt\n' > "$DOWNLOAD_CACHE/$key"
  download "$url" "$tmpdir/download-third"
  cmp "$tmpdir/download-source" "$tmpdir/download-third"
)
echo "Persistent download-cache integrity checks: PASS"

# Execute the embedded display policy with two outputs. A lower-resolution
# current output must not win over the other output's EDID-preferred 4K mode.
awk '/^python3 - "\$cfg" "\$json" "\$state_dir\/moonlight-display.env" <<'"'"'PY'"'"'$/{copy=1; next} copy && /^PY$/{exit} copy{print}' \
  "$PROFILE/rootfs/customize.d/20-media-steam.sh.inc" > "$tmpdir/moonlight-display-policy.py"
cat > "$tmpdir/moonlight-outputs.json" <<'EOF'
[
  {"name":"HDMI-A-1","enabled":true,"modes":[{"width":1920,"height":1080,"refresh":60000,"current":true}]},
  {"name":"HDMI-A-2","enabled":true,"modes":[{"width":3840,"height":2160,"refresh":60000,"preferred":true}]}
]
EOF
printf '[General]\nwidth=1280\nheight=720\nfps=60\nvideodec=1\n' > "$tmpdir/Moonlight.conf"
python3 "$tmpdir/moonlight-display-policy.py" "$tmpdir/Moonlight.conf" "$tmpdir/moonlight-outputs.json" "$tmpdir/moonlight-display.env" >/dev/null
grep -qx 'width=3840' "$tmpdir/Moonlight.conf"
grep -qx 'height=2160' "$tmpdir/Moonlight.conf"
grep -qx 'OUTPUT_NAME=HDMI-A-2' "$tmpdir/moonlight-display.env"
echo "Moonlight multi-output selection check: PASS"

# Run the one-time audio helper against a deterministic wpctl fixture.
awk '/^cat > \/usr\/local\/bin\/opi-audio-initial-default <<'"'"'EOF'"'"'$/{copy=1; next} copy && /^EOF$/{exit} copy{print}' \
  "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc" > "$tmpdir/opi-audio-initial-default"
chmod +x "$tmpdir/opi-audio-initial-default"
mkdir -p "$tmpdir/bin" "$tmpdir/audio-home"
cat > "$tmpdir/bin/wpctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == status ]]; then
  cat <<'STATUS'
Audio
 ├─ Sinks:
 │  * 42. HDMI / DisplayPort Output
 ├─ Sources:
STATUS
elif [[ "$1" == set-default && "$2" == 42 ]]; then
  printf '%s\n' "$2" > "${AUDIO_TEST_SELECTED:?}"
else
  exit 1
fi
EOF
chmod +x "$tmpdir/bin/wpctl"
PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/audio-home" AUDIO_TEST_SELECTED="$tmpdir/audio-selected" "$tmpdir/opi-audio-initial-default" >/dev/null
grep -qx 42 "$tmpdir/audio-selected"
grep -Fq 'HDMI_DEFAULT_SINK=' "$tmpdir/audio-home/.local/state/opi/audio-initial-default.env"
echo "One-time HDMI audio policy check: PASS"

# Until image finalization, the repository may inventory/SMART-check NVMe but
# must never partition, format, mount, migrate to, or write the installed NVMe.
! grep -ERni --include='*.sh' --include='*.inc' '(mkfs([.]|[[:space:]])|wipefs|sfdisk|parted|nvme[[:space:]]+format)' "$PROFILE"
awk '/cat > \/usr\/local\/bin\/opi-nvme-check /{copy=1; next} copy && /^EOF$/{exit} copy{print}' \
  "$PROFILE/rootfs/customize.d/50-runtime-validation.sh.inc" > "$tmpdir/opi-nvme-check"
[[ -s "$tmpdir/opi-nvme-check" ]]
bash -n "$tmpdir/opi-nvme-check"
grep -Fq 'nvme smart-log "$dev"' "$tmpdir/opi-nvme-check"
! grep -Eqi '(^|[^[:alnum:]_])(mount|umount|mkfs|wipefs|fdisk|sfdisk|parted|dd)([^[:alnum:]_]|$)' "$tmpdir/opi-nvme-check"

# Keep the repository handbook navigable. External URLs are curated separately;
# this pass proves every relative Markdown file/path reference exists.
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()
required = {
    "SECURITY.md",
    "docs/ARCHITECTURE.md",
    "docs/BUILDING.md",
    "docs/COMPONENTS.md",
    "docs/DESIGN-DECISIONS.md",
    "docs/EMULATION.md",
    "docs/OPERATIONS.md",
    "docs/REFERENCES.md",
    "docs/RELEASE-PROCESS.md",
    "docs/REQUIREMENTS.md",
    "docs/STORAGE.md",
    "docs/TROUBLESHOOTING.md",
    "docs/VALIDATION.md",
    "docs/VALIDATION-RECORD-TEMPLATE.md",
    "docs/V3.22-AUDIT.md",
    "docs/V3.23-AUDIT.md",
    "docs/V3.24-AUDIT.md",
    "docs/V3.25-AUDIT.md",
}
missing_required = sorted(path for path in required if not (root / path).is_file())
if missing_required:
    raise SystemExit("Missing required handbook files: " + ", ".join(missing_required))

link_re = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
failures = []
checked = 0
for source in sorted(root.rglob("*.md")):
    if ".git" in source.parts:
        continue
    text = source.read_text(encoding="utf-8")
    for raw in link_re.findall(text):
        target = raw.strip().split()[0].strip("<>")
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        path = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if not path:
            continue
        resolved = (source.parent / path).resolve()
        checked += 1
        if root not in resolved.parents and resolved != root:
            failures.append(f"{source.relative_to(root)}: escapes repository: {target}")
        elif not resolved.exists():
            failures.append(f"{source.relative_to(root)}: missing target: {target}")
if failures:
    raise SystemExit("Markdown link errors:\n" + "\n".join(failures))
print(f"Documentation link checks: PASS ({checked} relative links)")
PY

echo "Static repository checks: PASS"
