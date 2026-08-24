say "Valve native ARM64 Steam public-beta seed (best effort)"
STEAM_SEEDED=false; STEAM_MANIFEST_URL="https://client-update.steamstatic.com/steam_client_publicbeta_linuxarm64"
if STEAM_MANIFEST="$(curl --retry 3 --retry-delay 2 -fsSL "$STEAM_MANIFEST_URL" 2>/dev/null)"; then STEAM_FILE="$(grep -oE 'bins_linuxarm64_linuxarm64\.zip\.[0-9a-fA-F]+' <<<"$STEAM_MANIFEST" | head -n1 || true)"; if [[ -n "$STEAM_FILE" ]] && download "https://client-update.steamstatic.com/${STEAM_FILE}" "$DOWNLOADS/steam-arm64.zip" && unzip -t "$DOWNLOADS/steam-arm64.zip" >/dev/null 2>&1; then mkdir -p "$ART/steam/rootfs/opt/opi-seed"; cp "$DOWNLOADS/steam-arm64.zip" "$ART/steam/rootfs/opt/opi-seed/steam-arm64.zip"; STEAM_SEEDED=true; good "Valve ARM64 Steam payload staged"; fi; fi
[[ "$STEAM_SEEDED" == true ]] || warn "Valve ARM64 Steam payload was not staged; bootstrap remains available"
GE_SEEDED=false
if [[ -n "$GE_URL" ]] && download "$GE_URL" "$DOWNLOADS/ge-proton-aarch64.tar.gz"; then mkdir -p "$ART/ge-proton/rootfs/opt/opi-seed"; cp "$DOWNLOADS/ge-proton-aarch64.tar.gz" "$ART/ge-proton/rootfs/opt/opi-seed/"; GE_SEEDED=true; good "GE-Proton AArch64 staged"; fi
jq --argjson steam "$STEAM_SEEDED" --argjson ge "$GE_SEEDED" '.components.steam_arm64_seeded=$steam | .components.ge_proton_aarch64_seeded=$ge' "$LOCK" > "${LOCK}.tmp"; mv "${LOCK}.tmp" "$LOCK"
say "Recording downloaded artifact hashes"
jq '.artifact_sha256={}' "$LOCK" > "${LOCK}.tmp"; mv "${LOCK}.tmp" "$LOCK"
while IFS= read -r -d '' artifact; do
    artifact_name="$(basename "$artifact")"
    artifact_hash="$(sha_file "$artifact")"
    jq --arg name "$artifact_name" --arg hash "$artifact_hash" '.artifact_sha256[$name]=$hash' "$LOCK" > "${LOCK}.tmp"
    mv "${LOCK}.tmp" "$LOCK"
done < <(find "$DOWNLOADS" -maxdepth 1 -type f -print0 | sort -z)
say "Checking artifact path collisions"
python3 - "$ART" <<'PY'
from pathlib import Path
import sys
art=Path(sys.argv[1]); seen={}; collisions=[]
for root in sorted(art.glob('*/rootfs')):
 owner=root.parent.name
 for path in root.rglob('*'):
  if not (path.is_file() or path.is_symlink()): continue
  rel=str(path.relative_to(root))
  if rel in seen: collisions.append((rel,seen[rel],owner))
  else: seen[rel]=owner
if collisions:
 print('Artifact file collisions would silently overwrite content:',file=sys.stderr)
 for rel,first,second in collisions: print(f'  {rel}: {first} <-> {second}',file=sys.stderr)
 raise SystemExit(1)
print(f'Artifact collision preflight: {len(seen)} unique file/symlink paths')
PY
say "Merging validated artifacts (root-safe)"
mkdir -p "$OVERLAY"
docker run --rm --platform linux/amd64 -v "$ART:/artifacts:ro" -v "$OVERLAY:/overlay" ubuntu:26.04 bash -ceu 'shopt -s nullglob; for d in /artifacts/*/rootfs; do cp -a "$d/." /overlay/; done'
RUNTIME_PKGS="${WORK}/runtime-packages.generated.txt"; find "$ART" -name runtime-packages.txt -type f -exec cat {} + 2>/dev/null | sed '/^[[:space:]]*$/d' | sort -u > "$RUNTIME_PKGS" || true
cp "$WORK/required-packages.base.txt" "$WORK/required-packages.txt"; cat "$RUNTIME_PKGS" >> "$WORK/required-packages.txt"; sort -u -o "$WORK/required-packages.txt" "$WORK/required-packages.txt"
