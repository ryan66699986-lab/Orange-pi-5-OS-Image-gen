arm64_build() {
    local name="$1" script="$2" out="${ART}/${1}"
    mkdir -p "$out"; bash -n "$script" || die "Generated ${name} build script has shell syntax errors"; say "ARM64 artifact: ${name}"
    docker run --rm --platform linux/arm64 --env-file "$PROFILE_DIR/sources.env" -e JOBS="$JOBS" -e "ESDE_COMMIT=$ESDE_COMMIT" -e "V4L2_FFMPEG_COMMIT=$V4L2_FFMPEG_COMMIT" -e "V4L2_FFMPEG_REPO=$V4L2_FFMPEG_REPO" -v "$SCRIPTS/arm64-common.sh:/arm64-common.sh:ro" -v "$script:/build.sh:ro" -v "$out:/out" ubuntu:26.04 bash /build.sh 2>&1 | tee "${out}/build.log"
}
