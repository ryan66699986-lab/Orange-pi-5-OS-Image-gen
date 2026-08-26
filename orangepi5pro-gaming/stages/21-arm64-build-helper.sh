arm64_build() {
    local name="$1" script="$2" out="${ART}/${1}" media_root tool_cache
    local -a extra_mounts=()
    mkdir -p "$out"; bash -n "$script" || die "Generated ${name} build script has shell syntax errors"; say "ARM64 artifact: ${name}"
    [[ -n "$BUILDER_IMAGE" ]] || die "ARM64 build-dependency image was not resolved"
    docker image inspect "$BUILDER_IMAGE" >/dev/null 2>&1 || die "ARM64 build-dependency image is unavailable: $BUILDER_IMAGE"
    tool_cache="$COMPILER_CACHE/tooling/$name"
    mkdir -p "$COMPILER_CACHE/ccache" "$tool_cache/cargo" "$tool_cache/go-build" "$tool_cache/go-mod"
    if [[ "$name" == moonlight ]]; then
        media_root="$ART/stremio-native/rootfs/opt/opi/media"
        [[ -x "$media_root/bin/ffmpeg" && -e "$media_root/lib/libavcodec.so" ]] || die "Moonlight requires the completed dedicated media artifact"
        extra_mounts=(-v "$media_root:/opt/opi/media:ro")
    fi
    docker run --rm --platform linux/arm64 --env-file "$PROFILE_DIR/sources.env" \
      -e JOBS="$JOBS" -e OPI_BUILD_DEPS_READY=1 \
      -e CCACHE_DIR=/compiler-cache -e "CCACHE_NAMESPACE=opi5pro-${name}" \
      -e CCACHE_COMPILERCHECK=content -e CCACHE_MAXSIZE=20G \
      -e CARGO_HOME=/tool-cache/cargo -e GOCACHE=/tool-cache/go-build -e GOMODCACHE=/tool-cache/go-mod \
      -e "ESDE_COMMIT=$ESDE_COMMIT" -e "MOONLIGHT_COMMIT=$MOONLIGHT_COMMIT" -e "SNES9X_COMMIT=$SNES9X_COMMIT" -e "PPSSPP_COMMIT=$PPSSPP_COMMIT" -e "RMG_COMMIT=$RMG_COMMIT" -e "FLYCAST_COMMIT=$FLYCAST_COMMIT" -e "MELONDS_COMMIT=$MELONDS_COMMIT" -e "AZAHAR_COMMIT=$AZAHAR_COMMIT" -e "V4L2_FFMPEG_COMMIT=$V4L2_FFMPEG_COMMIT" -e "V4L2_FFMPEG_REPO=$V4L2_FFMPEG_REPO" -e "STREMIO_COMMIT=$STREMIO_COMMIT" -e "MPV_COMMIT=$MPV_COMMIT" \
      "${extra_mounts[@]}" \
      -v "$COMPILER_CACHE/ccache:/compiler-cache" -v "$tool_cache:/tool-cache" \
      -v "$SCRIPTS/arm64-common.sh:/arm64-common.sh:ro" -v "$script:/build.sh:ro" -v "$out:/out" \
      "$BUILDER_IMAGE" bash -ceu "trap 'ccache --show-stats || true' EXIT; bash /build.sh" 2>&1 | tee "${out}/build.log"
}
