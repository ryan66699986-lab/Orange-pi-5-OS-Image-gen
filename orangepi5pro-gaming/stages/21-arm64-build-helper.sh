arm64_build() {
    local name="$1" script="$2" out="${ART}/${1}" media_root
    local -a extra_mounts=()
    mkdir -p "$out"; bash -n "$script" || die "Generated ${name} build script has shell syntax errors"; say "ARM64 artifact: ${name}"
    if [[ "$name" == moonlight ]]; then
        media_root="$ART/stremio-native/rootfs/opt/opi/media"
        [[ -x "$media_root/bin/ffmpeg" && -e "$media_root/lib/libavcodec.so" ]] || die "Moonlight requires the completed dedicated media artifact"
        extra_mounts=(-v "$media_root:/opt/opi/media:ro")
    fi
    docker run --rm --platform linux/arm64 --env-file "$PROFILE_DIR/sources.env" -e JOBS="$JOBS" -e "ESDE_COMMIT=$ESDE_COMMIT" -e "MOONLIGHT_COMMIT=$MOONLIGHT_COMMIT" -e "SNES9X_COMMIT=$SNES9X_COMMIT" -e "PPSSPP_COMMIT=$PPSSPP_COMMIT" -e "RMG_COMMIT=$RMG_COMMIT" -e "FLYCAST_COMMIT=$FLYCAST_COMMIT" -e "MELONDS_COMMIT=$MELONDS_COMMIT" -e "AZAHAR_COMMIT=$AZAHAR_COMMIT" -e "V4L2_FFMPEG_COMMIT=$V4L2_FFMPEG_COMMIT" -e "V4L2_FFMPEG_REPO=$V4L2_FFMPEG_REPO" -e "STREMIO_COMMIT=$STREMIO_COMMIT" -e "MPV_COMMIT=$MPV_COMMIT" "${extra_mounts[@]}" -v "$SCRIPTS/arm64-common.sh:/arm64-common.sh:ro" -v "$script:/build.sh:ro" -v "$out:/out" ubuntu:26.04 bash /build.sh 2>&1 | tee "${out}/build.log"
}
