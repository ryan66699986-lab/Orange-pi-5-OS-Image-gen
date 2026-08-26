say "OpenCode ARM64"
download "$OPENCODE_URL" "$DOWNLOADS/opencode.tar.gz"
mkdir -p "$ART/opencode/rootfs/usr/local/bin" "$WORK/opencode-extract"
tar -xzf "$DOWNLOADS/opencode.tar.gz" -C "$WORK/opencode-extract"
OPENCODE_BIN="$(find "$WORK/opencode-extract" -type f -name opencode -perm -u+x | head -n1)"
[[ -n "$OPENCODE_BIN" ]] || die "Could not locate OpenCode executable"
assert_aarch64_host_file "$OPENCODE_BIN"
install -m755 "$OPENCODE_BIN" "$ART/opencode/rootfs/usr/local/bin/opencode"
docker run --rm --platform linux/arm64 -v "$ART/opencode/rootfs/usr/local/bin/opencode:/usr/local/bin/opencode:ro" ubuntu:26.04 /usr/local/bin/opencode --version
sha_file "$DOWNLOADS/opencode.tar.gz" > "$ART/opencode/source.sha256"
say "Preparing host-native AppImage extraction image"
docker pull --platform linux/amd64 ubuntu:26.04 >/dev/null
install -Dm0755 "$PROFILE_DIR/recipes/extract-appimage.sh" "$SCRIPTS/extract-appimage.sh"
extract_appimage() {
    local name="$1" url="$2" expected_sha="${3:-}" dl="${DOWNLOADS}/${1}.AppImage" out="${ART}/${1}"
    say "Official ARM64 AppImage: ${name}"; download "$url" "$dl"; assert_aarch64_host_file "$dl"; mkdir -p "$out/input"; cp "$dl" "$out/input/app.AppImage"
    if [[ -n "$expected_sha" ]]; then
        actual_sha="$(sha_file "$dl")"
        [[ "$actual_sha" == "$expected_sha" ]] || die "${name}: pinned AppImage SHA-256 mismatch (expected ${expected_sha}, got ${actual_sha})"
    fi
    docker run --rm --platform linux/amd64 -e APPNAME="$name" -v "$SCRIPTS/arm64-common.sh:/arm64-common.sh:ro" -v "$SCRIPTS/extract-appimage.sh:/build.sh:ro" -v "$out/input:/input:ro" -v "$out:/out" ubuntu:26.04 bash /build.sh
    [[ -x "$out/rootfs/opt/opi/apps/$name/AppRun" ]] || die "${name}: AppRun missing after extraction"
    rm -rf -- "$out/input"; sha_file "$dl" > "$out/source.sha256"
}
extract_appimage duckstation "$DUCK_URL" "$DUCK_ARM64_SHA256"
extract_appimage armsx2 "$ARMSX2_URL"
install -Dm0755 "$PROFILE_DIR/recipes/build-ppsspp.sh" "$SCRIPTS/build-ppsspp.sh"
