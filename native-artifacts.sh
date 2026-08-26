#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly RECIPES="${PROJECT_ROOT}/orangepi5pro-gaming/recipes"
readonly SOURCES="${PROJECT_ROOT}/orangepi5pro-gaming/sources.env"
readonly ARTIFACT_INPUT="${1:?artifact input directory required}"
readonly OUTPUT="${2:?native output directory required}"
readonly JOBS="${OPI_NATIVE_JOBS:-2}"
readonly ARM64_IMAGE="ubuntu:26.04"
readonly HOST_IMAGE="ubuntu:26.04"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
say() { printf '\n  -> %s\n' "$*"; }

[[ "${JOBS}" =~ ^[1-9][0-9]*$ ]] || die "OPI_NATIVE_JOBS must be a positive integer"
[[ -r "${SOURCES}" ]] || die "Missing source lock: ${SOURCES}"
[[ ! -e "${OUTPUT}" ]] || die "Native output path must not already exist: ${OUTPUT}"
mkdir -p "${OUTPUT}/builds" "${OUTPUT}/rootfs" "${OUTPUT}/meta"

say "Checking ARM64 container execution"
arch="$(docker run --rm --platform linux/arm64 "${ARM64_IMAGE}" uname -m 2>/dev/null || true)"
[[ "${arch}" == aarch64 ]] || die "Docker cannot execute ARM64 containers. On Debian/Ubuntu install qemu-user-static and binfmt-support, then rerun."

build_native() {
    local name="$1" recipe="$2" out="${OUTPUT}/builds/$1"
    shift 2
    say "Building native ARM64 ${name}"
    mkdir -p "${out}"
    docker run --rm --platform linux/arm64 \
        --env-file "${SOURCES}" \
        -e JOBS="${JOBS}" \
        -v "${RECIPES}/arm64-common.sh:/arm64-common.sh:ro" \
        -v "${RECIPES}/${recipe}:/build.sh:ro" \
        -v "${out}:/out" \
        "$@" \
        "${ARM64_IMAGE}" bash /build.sh
    [[ -d "${out}/rootfs" ]] || die "${name} did not produce a rootfs"
    [[ -f "${out}/runtime-packages.txt" ]] || die "${name} did not produce a runtime manifest"
}

extract_appimage() {
    local name="$1" source="$2" out="${OUTPUT}/builds/$1" input="${OUTPUT}/builds/$1-input"
    say "Extracting native ARM64 ${name} AppImage"
    [[ -s "${source}" ]] || die "Missing AppImage: ${source}"
    mkdir -p "${out}" "${input}"
    cp -a "${source}" "${input}/app.AppImage"
    docker run --rm \
        -e APPNAME="${name}" \
        -v "${RECIPES}/arm64-common.sh:/arm64-common.sh:ro" \
        -v "${RECIPES}/extract-appimage.sh:/build.sh:ro" \
        -v "${input}:/input:ro" \
        -v "${out}:/out" \
        "${HOST_IMAGE}" bash /build.sh
    [[ -x "${out}/rootfs/opt/opi/apps/${name}/AppRun" ]] || die "${name} extraction is incomplete"
    rm -rf -- "${input}"
}

build_probes() {
    local out="${OUTPUT}/rootfs/opt/opi-hw-probes"
    say "Generating hardware-decoder acceptance probes"
    mkdir -p "${out}"
    docker run --rm -v "${out}:/out" "${HOST_IMAGE}" bash -Eeuo pipefail -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update >/dev/null
        apt-get install -y --no-install-recommends ffmpeg >/dev/null
        ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=640x360:rate=30" -t 2 -pix_fmt yuv420p -c:v libx264 -preset ultrafast -movflags +faststart /out/h264.mp4
        ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=640x360:rate=30" -t 2 -pix_fmt yuv420p10le -c:v libx265 -preset ultrafast -x265-params log-level=error -movflags +faststart /out/hevc-main10.mp4
        ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p -c:v libx264 -preset ultrafast -movflags +faststart /out/h264-4k.mp4
        ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p10le -c:v libx265 -preset ultrafast -x265-params log-level=error -movflags +faststart /out/hevc-main10-4k.mp4
        ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -row-mt 1 /out/vp9-4k.webm
        ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p -c:v libaom-av1 -cpu-used 8 -row-mt 1 -tiles 2x2 -strict experimental /out/av1-4k.mkv
        test "$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of csv=p=0 /out/hevc-main10.mp4)" = "Main 10"
        for file in /out/*-4k.*; do
            test "$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file")" = 3840
            test "$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file")" = 2160
        done
    '
}

build_native stremio-native build-stremio-native.sh
build_native moonlight build-moonlight.sh \
    -v "${OUTPUT}/builds/stremio-native/rootfs/opt/opi/media:/opt/opi/media:ro"
build_native gamepad-osk build-gamepad-osk.sh
build_native ppsspp build-ppsspp.sh
build_native rmg build-rmg.sh
build_native flycast build-flycast.sh
build_native melonds build-melonds.sh
build_native azahar build-azahar.sh
build_native snes9x build-snes9x.sh

extract_appimage duckstation "${ARTIFACT_INPUT}/DuckStation-arm64.AppImage"
extract_appimage armsx2 "${ARTIFACT_INPUT}/ARMSX2-arm64.AppImage"
build_probes

say "Merging native root files and runtime package manifests"
for build in "${OUTPUT}"/builds/*; do
    [[ -d "${build}/rootfs" ]] || continue
    rsync -a "${build}/rootfs/." "${OUTPUT}/rootfs/"
    [[ -f "${build}/runtime-packages.txt" ]] && cat "${build}/runtime-packages.txt" >> "${OUTPUT}/meta/runtime-packages.txt"
done
sort -u -o "${OUTPUT}/meta/runtime-packages.txt" "${OUTPUT}/meta/runtime-packages.txt"

for required in \
    opt/stremio/stremio \
    opt/stremio/libopi-stremio-hwdec.so \
    opt/opi/media/bin/ffmpeg \
    opt/opi/media/bin/mpv \
    opt/opi/apps/ppsspp/PPSSPPSDL \
    opt/opi/apps/duckstation/AppRun \
    opt/opi/apps/armsx2/AppRun; do
    [[ -e "${OUTPUT}/rootfs/${required}" ]] || die "Merged native rootfs is missing ${required}"
done

printf 'Native artifact root: %s\n' "${OUTPUT}/rootfs"
