say "Input-keyed ARM64 build-dependency image"
BUILDER_CACHE_SCHEMA="v1-ubuntu26.04-arm64-ccache"
docker pull --platform linux/arm64 ubuntu:26.04 >/dev/null
UBUNTU_ARM64_IMAGE_ID="$(docker image inspect ubuntu:26.04 --format '{{.Id}}')"
[[ "$UBUNTU_ARM64_IMAGE_ID" =~ ^sha256:[0-9a-f]{64}$ ]] || die "Could not resolve Ubuntu 26.04 ARM64 image ID"
BUILDER_IMAGE_KEY="$({
    printf '%s\n%s\n' "$BUILDER_CACHE_SCHEMA" "$UBUNTU_ARM64_IMAGE_ID"
    sha256sum "$WORK/build-package-groups.txt"
} | sha256sum | awk '{print $1}')"
BUILDER_IMAGE="${BUILDER_IMAGE_REPOSITORY}:${BUILDER_IMAGE_KEY:0:24}"

verify_builder_image() {
    docker run --rm --platform linux/arm64 \
      -v "$WORK/build-package-groups.txt:/build-package-groups.txt:ro" \
      "$BUILDER_IMAGE" bash -seu <<'BUILDER_DEPS'
[[ "$(dpkg --print-architecture)" == arm64 ]]
command -v ccache >/dev/null
required=(ca-certificates git curl file binutils ccache)
while IFS='|' read -r name packages; do
  [[ -n "$name" ]] || continue
  read -r -a group <<<"$packages"
  required+=("${group[@]}")
done < /build-package-groups.txt
mapfile -t required < <(printf '%s\n' "${required[@]}" | sed '/^$/d' | sort -u)
for pkg in "${required[@]}"; do
  dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -qx 'install ok installed' || {
    echo "Cached ARM64 builder dependency is missing: $pkg" >&2
    exit 1
  }
done
BUILDER_DEPS
}

if docker image inspect "$BUILDER_IMAGE" >/dev/null 2>&1; then
    [[ "$(docker image inspect "$BUILDER_IMAGE" --format '{{ index .Config.Labels "org.opi5pro.builder-cache-key" }}')" == "$BUILDER_IMAGE_KEY" ]] || die "Builder dependency image label does not match its content key"
    verify_builder_image || die "Cached ARM64 build-dependency image failed verification"
    good "Verified ARM64 build-dependency cache hit: ${BUILDER_IMAGE}"
else
    CACHE_CONTAINER="opi5pro-builddeps-${PROFILE_VERSION//./-}-$$"
    docker rm -f "$CACHE_CONTAINER" >/dev/null 2>&1 || true
    if ! docker run --name "$CACHE_CONTAINER" --platform linux/arm64 \
      -v "$WORK/build-package-groups.txt:/build-package-groups.txt:ro" \
      ubuntu:26.04 bash -seu <<'BUILDER_DEPS'
export DEBIAN_FRONTEND=noninteractive
sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' \
  /etc/apt/sources.list.d/ubuntu.sources
required=(ca-certificates git curl file binutils ccache)
while IFS='|' read -r name packages; do
  [[ -n "$name" ]] || continue
  read -r -a group <<<"$packages"
  required+=("${group[@]}")
done < /build-package-groups.txt
mapfile -t required < <(printf '%s\n' "${required[@]}" | sed '/^$/d' | sort -u)
apt-get update
apt-get install -y --no-install-recommends "${required[@]}"
for pkg in "${required[@]}"; do
  dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -qx 'install ok installed' || {
    echo "New ARM64 builder dependency is missing: $pkg" >&2
    exit 1
  }
done
BUILDER_DEPS
    then
        docker rm -f "$CACHE_CONTAINER" >/dev/null 2>&1 || true
        die "Unable to construct ARM64 build-dependency image"
    fi
    if ! docker commit \
      --change "LABEL org.opi5pro.builder-cache-key=${BUILDER_IMAGE_KEY}" \
      --change "LABEL org.opi5pro.builder-cache-schema=${BUILDER_CACHE_SCHEMA}" \
      "$CACHE_CONTAINER" "$BUILDER_IMAGE" >/dev/null; then
        docker rm -f "$CACHE_CONTAINER" >/dev/null 2>&1 || true
        die "Unable to commit ARM64 build-dependency image"
    fi
    docker rm -f "$CACHE_CONTAINER" >/dev/null
    verify_builder_image || die "New ARM64 build-dependency image failed verification"
    good "Created verified ARM64 build-dependency image: ${BUILDER_IMAGE}"
fi

printf 'builder_image=%s\nbuilder_cache_key=%s\nubuntu_arm64_image_id=%s\n' \
  "$BUILDER_IMAGE" "$BUILDER_IMAGE_KEY" "$UBUNTU_ARM64_IMAGE_ID" \
  > "$WORK/builder-cache.meta"
export BUILDER_IMAGE
