say "Content-addressed ARM64 native-build base"

# Keep the ARM64 base under a private content-addressed tag. Later stages pull
# an amd64 Ubuntu image for AppImage extraction, so using ubuntu:26.04 directly
# for native builds would allow the host tag to change architecture mid-build.
# Dependencies are deliberately installed per recipe: their complete union is
# not solvable because upstreams require conflicting curl development providers.
docker pull --platform linux/arm64 ubuntu:26.04 >/dev/null
UBUNTU_ARM64_IMAGE_ID="$(docker image inspect ubuntu:26.04 --format '{{.Id}}')"
UBUNTU_ARM64_ARCH="$(docker image inspect ubuntu:26.04 --format '{{.Architecture}}')"
[[ "$UBUNTU_ARM64_IMAGE_ID" =~ ^sha256:[0-9a-f]{64}$ ]] || die "Could not resolve Ubuntu 26.04 ARM64 image ID"
[[ "$UBUNTU_ARM64_ARCH" == arm64 ]] || die "Ubuntu 26.04 native-build base is not ARM64: ${UBUNTU_ARM64_ARCH}"

BUILDER_IMAGE="${BUILDER_IMAGE_REPOSITORY}:${UBUNTU_ARM64_IMAGE_ID#sha256:}"
BUILDER_IMAGE="${BUILDER_IMAGE:0:${#BUILDER_IMAGE_REPOSITORY}+1+24}"
docker tag "$UBUNTU_ARM64_IMAGE_ID" "$BUILDER_IMAGE"
[[ "$(docker image inspect "$BUILDER_IMAGE" --format '{{.Id}}')" == "$UBUNTU_ARM64_IMAGE_ID" ]] || die "Private ARM64 build-base tag changed image identity"
[[ "$(docker image inspect "$BUILDER_IMAGE" --format '{{.Architecture}}')" == arm64 ]] || die "Private native-build base tag is not ARM64"

BASE_RECEIPT="$(docker run --rm --platform linux/arm64 "$BUILDER_IMAGE" \
  bash -ceu 'printf "schema=v2-plain-arm64-base\narchitecture=%s\n" "$(dpkg --print-architecture)"')"
grep -qx 'schema=v2-plain-arm64-base' <<<"$BASE_RECEIPT" || die "ARM64 build-base verification receipt is missing"
grep -qx 'architecture=arm64' <<<"$BASE_RECEIPT" || die "ARM64 build-base container reports the wrong architecture"

printf 'builder_image=%s\nubuntu_arm64_image_id=%s\narchitecture=%s\nschema=v2-plain-arm64-base\n' \
  "$BUILDER_IMAGE" "$UBUNTU_ARM64_IMAGE_ID" "$UBUNTU_ARM64_ARCH" \
  > "$WORK/builder-base.meta"
jq --arg image_id "$UBUNTU_ARM64_IMAGE_ID" \
  '.ubuntu_arm64_image_id=$image_id' "$LOCK" > "${LOCK}.tmp"
mv "${LOCK}.tmp" "$LOCK"
good "Verified content-addressed ARM64 build base: ${BUILDER_IMAGE}"
export BUILDER_IMAGE
