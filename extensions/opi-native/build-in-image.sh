#!/usr/bin/env bash
set -Eeuo pipefail

readonly BUILD_ROOT=/tmp/opi-native-build
readonly RECIPES="${BUILD_ROOT}/recipes"
readonly SOURCE_LOCK="${BUILD_ROOT}/sources.env"
readonly JOBS="${OPI_NATIVE_JOBS:-4}"
readonly RUNTIME_PACKAGES=/tmp/opi-runtime-packages.txt
readonly MANUAL_BEFORE=/tmp/opi-manual-before.txt

export DEBIAN_FRONTEND=noninteractive
export JOBS
set -a
source "${SOURCE_LOCK}"
set +a

[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo "Native builds require an arm64 rootfs" >&2; exit 1; }
[[ "${JOBS}" =~ ^[1-9][0-9]*$ ]] || { echo "OPI_NATIVE_JOBS must be a positive integer" >&2; exit 1; }

if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
    sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources
fi
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git jq openssl rsync squashfs-tools file binutils
apt-mark showmanual | sort -u > "${MANUAL_BEFORE}"
: > "${RUNTIME_PACKAGES}"
install -m755 "${RECIPES}/arm64-common.sh" /arm64-common.sh

download() {
    local destination="$1" url="$2" checksum="$3"
    curl --fail --location --retry 3 --retry-delay 2 --output "${destination}" "${url}"
    printf '%s  %s\n' "${checksum}" "${destination}" | sha256sum --check --status
}

merge_output() {
    [[ -d /out/rootfs ]] || { echo "Build produced no rootfs: $1" >&2; exit 1; }
    cp -a /out/rootfs/. /
    [[ -f /out/runtime-packages.txt ]] && cat /out/runtime-packages.txt >> "${RUNTIME_PACKAGES}"
}

run_recipe() {
    local name="$1" recipe="$2"
    echo "==> Building native AArch64 ${name}"
    rm -rf -- /src /out /ffmpeg /mpv /stremio /input
    mkdir -p /out
    bash "${RECIPES}/${recipe}"
    merge_output "${name}"
}

extract_appimage() {
    local name="$1" source="$2"
    echo "==> Extracting native AArch64 ${name}"
    rm -rf -- /out /input
    mkdir -p /out /input
    install -m755 "${source}" /input/app.AppImage
    APPNAME="${name}" bash "${RECIPES}/extract-appimage.sh"
    merge_output "${name}"
}

mkdir -p /tmp/opi-downloads
download /tmp/opi-downloads/es-de.AppImage "${ESDE_ARM64_URL}" "${ESDE_ARM64_SHA256}"
download /tmp/opi-downloads/opencode.tar.gz "${OPENCODE_ARM64_URL}" "${OPENCODE_ARM64_SHA256}"
download /tmp/opi-downloads/brave-keyring.deb "${BRAVE_KEYRING_URL}" "${BRAVE_KEYRING_SHA256}"
download /tmp/opi-downloads/brave-browser.deb "${BRAVE_ARM64_URL}" "${BRAVE_ARM64_SHA256}"
download /tmp/opi-downloads/armsx2.AppImage \
    "https://github.com/ARMSX2/ARMSX2/releases/download/${ARMSX2_TAG}/ARMSX2-${ARMSX2_TAG}-1b737e25f0-Linux-arm64-4K-pages.AppImage" \
    "${ARMSX2_SHA256}"

duck_url="$(curl --fail --location --retry 3 "https://api.github.com/repos/stenzek/duckstation/releases/${DUCK_RELEASE_ID}" | jq -er '.assets[] | select(.name == "DuckStation-arm64.AppImage") | .browser_download_url')"
download /tmp/opi-downloads/duckstation.AppImage "${duck_url}" "${DUCK_ARM64_SHA256}"
unset duck_url

install -Dm755 /tmp/opi-downloads/es-de.AppImage /opt/es-de/ES-DE.AppImage
tar -xzf /tmp/opi-downloads/opencode.tar.gz -C /tmp/opi-downloads
install -Dm755 /tmp/opi-downloads/opencode /usr/local/bin/opencode
apt-get install -y --no-install-recommends /tmp/opi-downloads/brave-keyring.deb /tmp/opi-downloads/brave-browser.deb

run_recipe stremio build-stremio-native.sh
run_recipe moonlight build-moonlight.sh
run_recipe gamepad-osk build-gamepad-osk.sh
run_recipe ppsspp build-ppsspp.sh
run_recipe rmg build-rmg.sh
run_recipe flycast build-flycast.sh
run_recipe melonds build-melonds.sh
run_recipe snes9x build-snes9x.sh
extract_appimage duckstation /tmp/opi-downloads/duckstation.AppImage
extract_appimage armsx2 /tmp/opi-downloads/armsx2.AppImage

sort -u -o "${RUNTIME_PACKAGES}" "${RUNTIME_PACKAGES}"
if [[ -s "${RUNTIME_PACKAGES}" ]]; then
    xargs -r apt-get install -y --no-install-recommends < "${RUNTIME_PACKAGES}"
fi
printf '%s\n' brave-browser brave-keyring nodejs qt6-qpa-plugins qt6-wayland >> "${RUNTIME_PACKAGES}"
sort -u -o "${RUNTIME_PACKAGES}" "${RUNTIME_PACKAGES}"

apt-mark showmanual | sort -u > /tmp/opi-manual-after.txt
comm -13 "${MANUAL_BEFORE}" /tmp/opi-manual-after.txt | xargs -r apt-mark auto
xargs -r apt-mark manual < "${RUNTIME_PACKAGES}"
apt-get autoremove -y --purge
apt-get clean

rm -rf -- /src /out /ffmpeg /mpv /stremio /input /tmp/opi-downloads \
    /tmp/opi-manual-after.txt "${MANUAL_BEFORE}" "${RUNTIME_PACKAGES}" /arm64-common.sh

echo "Native AArch64 application build complete"
