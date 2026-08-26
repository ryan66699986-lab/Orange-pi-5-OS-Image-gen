say "ARM64 merged-artifact runtime closure preflight"
CLOSURE_PKGS="$WORK/runtime-packages.closure.txt"
CLOSURE_RECEIPT="$WORK/runtime-closure.receipt"
: > "$CLOSURE_PKGS"
: > "$CLOSURE_RECEIPT"
install -Dm0755 "$PROFILE_DIR/recipes/runtime-closure.sh" "$SCRIPTS/runtime-closure.sh"

docker run --rm --platform linux/arm64 \
  -v "$OVERLAY:/overlay:ro" \
  -v "$WORK/required-packages.txt:/required-packages.txt:ro" \
  -v "$SCRIPTS/arm64-common.sh:/arm64-common.sh:ro" \
  -v "$SCRIPTS/runtime-closure.sh:/runtime-closure.sh:ro" \
  -v "$CLOSURE_PKGS:/runtime-packages.closure.txt" \
  -v "$CLOSURE_RECEIPT:/runtime-closure.receipt" \
  "$BUILDER_IMAGE" bash /runtime-closure.sh

grep -qx 'schema=opi-runtime-closure-v2' "$CLOSURE_RECEIPT" || die "Runtime closure did not produce the expected schema receipt"
grep -qx 'architecture=arm64' "$CLOSURE_RECEIPT" || die "Runtime closure did not prove ARM64 execution"
grep -qx 'result=PASS' "$CLOSURE_RECEIPT" || die "Runtime closure did not produce a PASS receipt"
core_count="$(sed -n 's/^core_dynamic_elf_count=//p' "$CLOSURE_RECEIPT")"
appimage_count="$(sed -n 's/^appimage_dynamic_elf_count=//p' "$CLOSURE_RECEIPT")"
package_count="$(sed -n 's/^package_count=//p' "$CLOSURE_RECEIPT")"
recorded_sha="$(sed -n 's/^package_sha256=//p' "$CLOSURE_RECEIPT")"
[[ "$core_count" =~ ^[0-9]+$ && "$appimage_count" =~ ^[0-9]+$ && "$package_count" =~ ^[0-9]+$ ]] || die "Runtime closure receipt has malformed counts"
(( core_count >= 10 && appimage_count >= 2 && package_count >= 5 )) || die "Runtime closure receipt is below mandatory coverage floors"
[[ -s "$CLOSURE_PKGS" ]] || die "Runtime closure produced an empty owning-package contract"
[[ "$recorded_sha" == "$(sha_file "$CLOSURE_PKGS")" ]] || die "Runtime closure receipt/package digest mismatch"

cat "$CLOSURE_PKGS" >> "$WORK/required-packages.txt"
sort -u -o "$WORK/required-packages.txt" "$WORK/required-packages.txt"
[[ -s "$WORK/required-packages.txt" ]] || die "Final explicit runtime package contract is empty"
good "Merged ARM64 runtime closure externally verified (${core_count} core + ${appimage_count} AppImage dynamic ELFs; ${package_count} packages)"
