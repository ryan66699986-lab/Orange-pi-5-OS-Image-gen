say "Resolving and validating component sources"
require_github_tag anomalyco/opencode "$OPENCODE_TAG"; OPENCODE_URL="https://github.com/anomalyco/opencode/releases/download/${OPENCODE_TAG}/opencode-linux-arm64.tar.gz"; require_download_url "$OPENCODE_URL" "OpenCode ${OPENCODE_TAG} ARM64 tarball"
STREMIO_COMMIT="$(remote_tag_commit "https://github.com/Stremio/stremio-linux-shell.git" "$STREMIO_TAG")"; [[ "$STREMIO_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve Stremio ${STREMIO_TAG} commit"
MPV_COMMIT="$(remote_tag_commit "https://github.com/mpv-player/mpv.git" "$MPV_TAG")"; [[ "$MPV_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve mpv ${MPV_TAG} commit"
MOONLIGHT_COMMIT="$(remote_tag_commit "https://github.com/moonlight-stream/moonlight-qt.git" "$MOONLIGHT_TAG")"; [[ "$MOONLIGHT_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve Moonlight ${MOONLIGHT_TAG} commit"
SNES9X_COMMIT="$(remote_tag_commit "https://github.com/snes9xgit/snes9x.git" "$SNES9X_TAG")"; [[ "$SNES9X_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve Snes9x ${SNES9X_TAG} commit"
PPSSPP_COMMIT="$(remote_tag_commit "https://github.com/hrydgard/ppsspp.git" "$PPSSPP_TAG")"; [[ "$PPSSPP_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve PPSSPP ${PPSSPP_TAG} commit"
RMG_COMMIT="$(remote_tag_commit "https://github.com/Rosalie241/RMG.git" "$RMG_TAG")"; [[ "$RMG_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve RMG ${RMG_TAG} commit"
FLYCAST_COMMIT="$(remote_tag_commit "https://github.com/flyinghead/flycast.git" "$FLYCAST_TAG")"; [[ "$FLYCAST_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve Flycast ${FLYCAST_TAG} commit"
MELONDS_COMMIT="$(remote_tag_commit "https://github.com/melonDS-emu/melonDS.git" "$MELONDS_TAG")"; [[ "$MELONDS_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve melonDS ${MELONDS_TAG} commit"
AZAHAR_COMMIT="$(remote_tag_commit "https://github.com/azahar-emu/azahar.git" "$AZAHAR_TAG")"; [[ "$AZAHAR_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve Azahar ${AZAHAR_TAG} commit"
require_github_commit 0x90shell/gamepad-osk "$GAMEPAD_OSK_COMMIT"
ESDE_REPO="es-de/emulationstation-de"; ESDE_COMMIT="$(remote_tag_commit "https://gitlab.com/${ESDE_REPO}.git" "$ESDE_TAG")"; [[ "$ESDE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve ES-DE commit for ${ESDE_TAG} via Git transport"
github_content_exists hrydgard/ppsspp "$PPSSPP_COMMIT" CMakeLists.txt; github_content_exists moonlight-stream/moonlight-qt "$MOONLIGHT_COMMIT" moonlight-qt.pro; github_content_exists Rosalie241/RMG "$RMG_COMMIT" CMakeLists.txt; github_content_exists flyinghead/flycast "$FLYCAST_COMMIT" CMakeLists.txt; github_content_exists melonDS-emu/melonDS "$MELONDS_COMMIT" CMakeLists.txt; github_content_exists azahar-emu/azahar "$AZAHAR_COMMIT" CMakeLists.txt; github_content_exists snes9xgit/snes9x "$SNES9X_COMMIT" gtk/CMakeLists.txt; github_content_exists 0x90shell/gamepad-osk "$GAMEPAD_OSK_COMMIT" go.mod; github_content_exists 0x90shell/gamepad-osk "$GAMEPAD_OSK_COMMIT" config.example; github_content_exists 0x90shell/gamepad-osk "$GAMEPAD_OSK_COMMIT" gamepad-osk.udev; github_content_exists Stremio/stremio-linux-shell "$STREMIO_COMMIT" Cargo.toml; github_content_exists Stremio/stremio-linux-shell "$STREMIO_COMMIT" Cargo.lock; github_content_exists Stremio/stremio-linux-shell "$STREMIO_COMMIT" data/server.js; github_content_exists Stremio/stremio-linux-shell "$STREMIO_COMMIT" data/com.stremio.Stremio.gschema.xml; github_content_exists mpv-player/mpv "$MPV_COMMIT" meson.build
STREMIO_CARGO_RAW="https://raw.githubusercontent.com/Stremio/stremio-linux-shell/${STREMIO_COMMIT}/Cargo.toml"; require_url_contains "$STREMIO_CARGO_RAW" 'v4_22' "Stremio GTK >= 4.22 feature requirement"; require_url_contains "$STREMIO_CARGO_RAW" 'v1_9' "Stremio libadwaita >= 1.9 feature requirement"; require_url_contains "$STREMIO_CARGO_RAW" 'v2_52' "Stremio WebKitGTK >= 2.52 feature requirement"
MOONLIGHT_FFMPEG_RAW="https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/${MOONLIGHT_COMMIT}/app/streaming/video/ffmpeg.cpp"; require_url_contains "$MOONLIGHT_FFMPEG_RAW" 'AV_PIX_FMT_DRM_PRIME|AV_HWDEVICE_TYPE_DRM' "Moonlight DRM_PRIME hardware decoder support"; require_url_contains "https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/${MOONLIGHT_COMMIT}/app/settings/streamingpreferences.h" 'VDS_FORCE_HARDWARE' "Moonlight force-hardware decoder mode"
require_url_contains "https://gitlab.com/es-de/emulationstation-de/-/raw/${ESDE_COMMIT}/CMakeLists.txt" 'VIDEO_HW_DECODING|DEINIT_ON_LAUNCH' "ES-DE CMake options"; require_url_contains "https://raw.githubusercontent.com/hrydgard/ppsspp/${PPSSPP_COMMIT}/CMakeLists.txt" 'PPSSPPSDL' "PPSSPP SDL target"; require_url_contains "https://raw.githubusercontent.com/azahar-emu/azahar/${AZAHAR_COMMIT}/CMakeLists.txt" 'ENABLE_VULKAN' "Azahar Vulkan option"
V4L2_FFMPEG_REPO="https://code.ffmpeg.org/Kwiboo/FFmpeg.git"; V4L2_FFMPEG_COMMIT="$(remote_branch_commit "$V4L2_FFMPEG_REPO" "$V4L2_FFMPEG_BRANCH")"; if [[ ! "$V4L2_FFMPEG_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then V4L2_FFMPEG_REPO="https://github.com/Kwiboo/FFmpeg.git"; V4L2_FFMPEG_COMMIT="$(remote_branch_commit "$V4L2_FFMPEG_REPO" "$V4L2_FFMPEG_BRANCH")"; fi; [[ "$V4L2_FFMPEG_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve ${V4L2_FFMPEG_BRANCH} from either Kwiboo FFmpeg remote"
[[ "$DUCK_RELEASE_ID" =~ ^[0-9]+$ ]] || die "DuckStation release ID is not pinned"
[[ "$DUCK_ARM64_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "DuckStation ARM64 SHA-256 is not pinned"
DUCK_TAG="release-${DUCK_RELEASE_ID}"; DUCK_URL="https://github.com/stenzek/duckstation/releases/download/latest/DuckStation-arm64.AppImage"; require_download_url "$DUCK_URL" "DuckStation ARM64 AppImage"
ARMSX2_COMMIT="$(remote_tag_commit "https://github.com/ARMSX2/ARMSX2.git" "$ARMSX2_TAG")"; [[ "$ARMSX2_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Unable to resolve ARMSX2 ${ARMSX2_TAG} commit"; ARMSX2_DATE="${ARMSX2_TAG#nightly-}"; [[ "$ARMSX2_DATE" =~ ^[0-9]{8}$ ]] || die "Unexpected ARMSX2 nightly tag format: ${ARMSX2_TAG}"; ARMSX2_SHORT="${ARMSX2_COMMIT:0:10}"; ARMSX2_ASSET="ARMSX2-nightly-${ARMSX2_DATE}-${ARMSX2_SHORT}-Linux-arm64-4K-pages.AppImage"; ARMSX2_URL="https://github.com/ARMSX2/ARMSX2/releases/download/${ARMSX2_TAG}/${ARMSX2_ASSET}"; require_download_url "$ARMSX2_URL" "ARMSX2 ${ARMSX2_TAG} Linux ARM64 4K AppImage"
GE_TAG="$GE_PROTON_TAG"; GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_TAG}/${GE_TAG}-aarch64.tar.gz"; GE_STATUS="$(head_status "$GE_URL")"; if [[ "$GE_STATUS" != 200 && "$GE_STATUS" != 206 ]]; then warn "Optional GE-Proton seed unavailable (HTTP ${GE_STATUS:-000}); continuing without it"; GE_TAG=""; GE_URL=""; fi
jq -n \
  --arg generated "$(date --iso-8601=seconds)" \
  --arg builder "v${PROFILE_VERSION}-repo" \
  --arg opencode "$OPENCODE_TAG" \
  --arg moonlight "$MOONLIGHT_TAG" --arg moonlight_commit "$MOONLIGHT_COMMIT" \
  --arg esde "$ESDE_TAG" --arg esde_commit "$ESDE_COMMIT" \
  --arg gamepad "$GAMEPAD_OSK_COMMIT" \
  --arg stremio "$STREMIO_TAG" --arg stremio_commit "$STREMIO_COMMIT" --arg stremio_hwdec "v4l2request-copy" \
  --arg ffmpeg_v4l2 "$V4L2_FFMPEG_BRANCH" --arg ffmpeg_repo "$V4L2_FFMPEG_REPO" --arg ffmpeg_commit "$V4L2_FFMPEG_COMMIT" \
  --arg mpv "$MPV_TAG" --arg mpv_commit "$MPV_COMMIT" \
  --arg ppsspp "$PPSSPP_TAG" --arg ppsspp_commit "$PPSSPP_COMMIT" \
  --arg rmg "$RMG_TAG" --arg rmg_commit "$RMG_COMMIT" \
  --arg flycast "$FLYCAST_TAG" --arg flycast_commit "$FLYCAST_COMMIT" \
  --arg melonds "$MELONDS_TAG" --arg melonds_commit "$MELONDS_COMMIT" \
  --arg azahar "$AZAHAR_TAG" --arg azahar_commit "$AZAHAR_COMMIT" \
  --arg snes9x "$SNES9X_TAG" --arg snes9x_commit "$SNES9X_COMMIT" \
  --arg duck "$DUCK_TAG" --arg duck_sha256 "$DUCK_ARM64_SHA256" \
  --arg armsx2 "$ARMSX2_TAG" --arg armsx2_commit "$ARMSX2_COMMIT" \
  --arg ge "$GE_TAG" \
  '{generated:$generated,builder:$builder,target:{board:"orangepi5pro",branch:"edge",release:"resolute",arch:"aarch64"},components:{opencode:$opencode,moonlight:$moonlight,moonlight_commit:$moonlight_commit,moonlight_hwdec_policy:"force-hardware-v4l2request",es_de:$esde,es_de_commit:$esde_commit,gamepad_osk_commit:$gamepad,stremio_linux_shell:$stremio,stremio_linux_shell_commit:$stremio_commit,stremio_hwdec_policy:$stremio_hwdec,ffmpeg_v4l2_request_branch:$ffmpeg_v4l2,ffmpeg_v4l2_request_repo:$ffmpeg_repo,ffmpeg_v4l2_request_commit:$ffmpeg_commit,mpv:$mpv,mpv_commit:$mpv_commit,ppsspp:$ppsspp,ppsspp_commit:$ppsspp_commit,rmg:$rmg,rmg_commit:$rmg_commit,flycast:$flycast,flycast_commit:$flycast_commit,melonds:$melonds,melonds_commit:$melonds_commit,azahar:$azahar,azahar_commit:$azahar_commit,snes9x:$snes9x,snes9x_commit:$snes9x_commit,duckstation:$duck,duckstation_sha256:$duck_sha256,armsx2:$armsx2,armsx2_commit:$armsx2_commit,ge_proton:$ge}}' > "$LOCK"
cat "$LOCK"; good "All mandatory source refs and recipe layouts resolve"
install -m0644 "$PROFILE_DIR/packages/base.txt" "$WORK/required-packages.base.txt"
install -m0644 "$PROFILE_DIR/packages/build-groups.txt" "$WORK/build-package-groups.txt"
