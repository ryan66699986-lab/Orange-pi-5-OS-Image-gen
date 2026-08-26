#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="$(<"${PROJECT_ROOT}/VERSION")"
readonly ARMBIAN_REF="${ARMBIAN_REF:-28699057f79dfd0c4114d8cf0405ccce0a098d0f}"
readonly BUILD_PARENT="${OPI_BUILD_PARENT:-${HOME}}"
readonly OUTPUT_DIR="${OPI_OUTPUT_DIR:-${HOME}/opi5pro-images/v${VERSION}}"
WORK_DIR=""

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }

cleanup() {
    local rc=$?
    trap - EXIT
    if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
        mkdir -p "${OUTPUT_DIR}/logs"
        if [[ -d "${WORK_DIR}/armbian/output/logs" ]]; then
            cp -a "${WORK_DIR}/armbian/output/logs/." "${OUTPUT_DIR}/logs/" 2>/dev/null || true
        fi
        rm -rf -- "${WORK_DIR}"
    fi
    exit "${rc}"
}
trap cleanup EXIT

for command in curl docker git openssl rsync; do
    command -v "${command}" >/dev/null 2>&1 || die "Missing host command: ${command}"
done
docker info >/dev/null 2>&1 || die "Docker is not available to this user"
[[ "${BUILD_PARENT}" != *' '* ]] || die "OPI_BUILD_PARENT must not contain spaces"
mkdir -p "${BUILD_PARENT}" "${OUTPUT_DIR}"

if [[ -n "${OPI_USER_PASSWORD_HASH:-}" ]]; then
    USER_PASSWORD_HASH="${OPI_USER_PASSWORD_HASH}"
else
    say "Initial password for user 'ryan'"
    read -r -s -p 'Password: ' first_password
    printf '\n'
    read -r -s -p 'Repeat:   ' second_password
    printf '\n'
    [[ -n "${first_password}" ]] || die "Password cannot be empty"
    [[ "${first_password}" == "${second_password}" ]] || die "Passwords do not match"
    USER_PASSWORD_HASH="$(printf '%s' "${first_password}" | openssl passwd -6 -stdin)"
    unset first_password second_password
fi
[[ "${USER_PASSWORD_HASH}" == \$6\$* ]] || die "Password hash must use SHA-512 crypt (prefix \$6\$)"

WORK_DIR="$(mktemp -d "${BUILD_PARENT%/}/opi5pro-v${VERSION}.XXXXXX")"
readonly WORK_DIR
readonly ARMBIAN_DIR="${WORK_DIR}/armbian"
readonly ARTIFACT_DIR="${WORK_DIR}/artifacts"
readonly NATIVE_DIR="${WORK_DIR}/native"
mkdir -p "${ARTIFACT_DIR}"

download() {
    local name="$1" url="$2" sha256="$3" destination="${ARTIFACT_DIR}/$1"
    say "Downloading ${name}"
    curl --fail --location --retry 3 --retry-delay 2 --output "${destination}" "${url}"
    printf '%s  %s\n' "${sha256}" "${destination}" | sha256sum --check --status \
        || die "Checksum failed for ${name}"
}

download ES-DE_aarch64.AppImage \
    https://gitlab.com/es-de/emulationstation-de/-/package_files/326321114/download \
    b84eababe6d6388223cf8b1658bb237bc0125362acaae70e1ece55397c1eb414
download opencode-linux-arm64.tar.gz \
    https://github.com/anomalyco/opencode/releases/download/v1.18.21/opencode-linux-arm64.tar.gz \
    d30d2cba74617f4e7b96e25563c9572ffe453f9eae70fc0df16286813537ee72
download brave-keyring.deb \
    https://brave-browser-apt-release.s3.brave.com/pool/main/b/brave-keyring/brave-keyring_1.20-1.deb \
    9ea8725ad4241e4d30bc31b0d5213c7ce24b1dcd5247875b2de1bcba8c4e9b00
download brave-browser.deb \
    https://brave-browser-apt-release.s3.brave.com/pool/main/b/brave-browser/brave-browser_1.93.138_arm64.deb \
    5965e7d90d9ac6187dfca53aeefeb07f8be64515ee6262476cd9b23afbef83d7
download DuckStation-arm64.AppImage \
    https://github.com/stenzek/duckstation/releases/download/latest/DuckStation-arm64.AppImage \
    e4bedd6285172cc3127fb2634f646d707b5df13e2176579caa39dd9b12ae75a8
download ARMSX2-arm64.AppImage \
    https://github.com/ARMSX2/ARMSX2/releases/download/nightly-20260823/ARMSX2-nightly-20260823-1b737e25f0-Linux-arm64-4K-pages.AppImage \
    2a4bb7b2aa6ef505e12c071733c160250308b784d4390c7953f8db3046981d0b

say "Building mandatory native ARM64 applications"
"${PROJECT_ROOT}/native-artifacts.sh" "${ARTIFACT_DIR}" "${NATIVE_DIR}"

say "Creating a fresh Armbian workspace"
git init -q "${ARMBIAN_DIR}"
git -C "${ARMBIAN_DIR}" remote add origin https://github.com/armbian/build.git
git -C "${ARMBIAN_DIR}" fetch --depth=1 origin "${ARMBIAN_REF}"
git -C "${ARMBIAN_DIR}" checkout -q --detach FETCH_HEAD

say "Checking the RK3588 hardware-decoder kernel configuration"
kernel_config="${ARMBIAN_DIR}/config/kernel/linux-rockchip64-edge.config"
for setting in \
    CONFIG_MEDIA_SUPPORT=m \
    CONFIG_VIDEO_ROCKCHIP_VDEC=m \
    CONFIG_VIDEO_HANTRO=m \
    CONFIG_VSI_IOMMU=y; do
    grep -qx "${setting}" "${kernel_config}" || die "Armbian edge kernel lacks ${setting}"
done
unset kernel_config setting

mkdir -p "${ARMBIAN_DIR}/userpatches/overlay/opi-artifacts"
rsync -a "${PROJECT_ROOT}/userpatches/." "${ARMBIAN_DIR}/userpatches/"
cp -a "${ARTIFACT_DIR}/." "${ARMBIAN_DIR}/userpatches/overlay/opi-artifacts/"
mkdir -p "${ARMBIAN_DIR}/userpatches/overlay/native-rootfs"
rsync -a "${NATIVE_DIR}/rootfs/." "${ARMBIAN_DIR}/userpatches/overlay/native-rootfs/"
runtime_packages="$(tr '\n' ' ' < "${NATIVE_DIR}/meta/runtime-packages.txt")"
printf '\nPACKAGE_LIST_ADDITIONAL+=" %s"\n' "${runtime_packages}" \
    >> "${ARMBIAN_DIR}/userpatches/config-opi5pro.conf"
unset runtime_packages
printf '%s\n' "${USER_PASSWORD_HASH}" > "${ARMBIAN_DIR}/userpatches/overlay/opi-user-password.hash"
chmod 600 "${ARMBIAN_DIR}/userpatches/overlay/opi-user-password.hash"
unset USER_PASSWORD_HASH

say "Building V${VERSION} with the standard Armbian framework"
(
    cd "${ARMBIAN_DIR}"
    ./compile.sh build opi5pro REVISION="${VERSION}.0"
)

say "Copying the uncompressed image and logs"
cp -a "${ARMBIAN_DIR}/output/images/." "${OUTPUT_DIR}/"
printf 'Image output: %s\n' "${OUTPUT_DIR}"
