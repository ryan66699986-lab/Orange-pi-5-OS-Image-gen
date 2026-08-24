for spec in "snes9x:build-snes9x.sh" "stremio-native:build-stremio-native.sh"; do
    name="${spec%%:*}"
    script="${spec#*:}"
    install -Dm0755 "$PROFILE_DIR/recipes/$script" "$SCRIPTS/$script"
    arm64_build "$name" "$SCRIPTS/$script"
done

arm64_build ppsspp "$SCRIPTS/build-ppsspp.sh"
for spec in "es-de:build-esde.sh" "gamepad-osk:build-gamepad-osk.sh" "moonlight:build-moonlight.sh" "rmg:build-rmg.sh" "flycast:build-flycast.sh" "melonds:build-melonds.sh" "azahar:build-azahar.sh"; do
    name="${spec%%:*}"
    script="${spec#*:}"
    install -Dm0755 "$PROFILE_DIR/recipes/$script" "$SCRIPTS/$script"
    arm64_build "$name" "$SCRIPTS/$script"
done

[[ "$(<"$ART/stremio-native/ffmpeg.commit")" == "$V4L2_FFMPEG_COMMIT" ]] || die "Built FFmpeg commit differs from source lock"
[[ "$(<"$ART/stremio-native/mpv.commit")" == "$MPV_COMMIT" ]] || die "Built mpv commit differs from source lock"
[[ "$(<"$ART/stremio-native/stremio.commit")" == "$STREMIO_COMMIT" ]] || die "Built Stremio commit differs from source lock"
[[ "$(<"$ART/snes9x/source.commit")" == "$SNES9X_COMMIT" ]] || die "Built Snes9x commit differs from source lock"
[[ "$(<"$ART/moonlight/source.commit")" == "$MOONLIGHT_COMMIT" ]] || die "Built Moonlight commit differs from source lock"
[[ "$(<"$ART/ppsspp/source.commit")" == "$PPSSPP_COMMIT" ]] || die "Built PPSSPP commit differs from source lock"
[[ "$(<"$ART/rmg/source.commit")" == "$RMG_COMMIT" ]] || die "Built RMG commit differs from source lock"
[[ "$(<"$ART/flycast/source.commit")" == "$FLYCAST_COMMIT" ]] || die "Built Flycast commit differs from source lock"
[[ "$(<"$ART/melonds/source.commit")" == "$MELONDS_COMMIT" ]] || die "Built melonDS commit differs from source lock"
[[ "$(<"$ART/azahar/source.commit")" == "$AZAHAR_COMMIT" ]] || die "Built Azahar commit differs from source lock"
for spec in "ppsspp:ppsspp_source_commit" "es-de:es_de_built_commit" "moonlight:moonlight_built_commit" "rmg:rmg_built_commit" "flycast:flycast_built_commit" "melonds:melonds_built_commit" "azahar:azahar_built_commit" "snes9x:snes9x_built_commit"; do
    name="${spec%%:*}"
    key="${spec#*:}"
    commit_file="$ART/$name/source.commit"
    [[ -s "$commit_file" ]] || die "${name} did not record its built source commit"
    commit="$(<"$commit_file")"
    [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "${name} recorded an invalid source commit: ${commit}"
    jq --arg key "$key" --arg commit "$commit" '.components[$key]=$commit' "$LOCK" > "${LOCK}.tmp"
    mv "${LOCK}.tmp" "$LOCK"
done
