#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/orangepi5pro-gaming"
receipt="$(mktemp)"
trap 'rm -f -- "$receipt"' EXIT

docker pull --platform linux/arm64 ubuntu:26.04 >/dev/null
[[ "$(docker image inspect ubuntu:26.04 --format '{{.Architecture}}')" == arm64 ]]

docker run --rm --platform linux/arm64 \
  -v "$PROFILE/recipes/arm64-common.sh:/arm64-common.sh:ro" \
  -v "$PROFILE/packages/build-groups.txt:/build-package-groups.txt:ro" \
  -v "$ROOT/tools/container-smoke-inner.sh:/container-smoke-inner.sh:ro" \
  -v "$receipt:/container-smoke.receipt" \
  ubuntu:26.04 bash /container-smoke-inner.sh

grep -qx 'schema=opi-container-smoke-v1' "$receipt"
grep -qx 'architecture=arm64' "$receipt"
grep -qx 'common_tools=PASS' "$receipt"
grep -qx 'isolated_groups=PASS' "$receipt"
grep -qx 'result=PASS' "$receipt"

# Negative controls: a container that never runs the mounted gate cannot leave
# a receipt, and a missing mandatory command must produce failure.
: > "$receipt"
docker run --rm --platform linux/arm64 -v "$receipt:/container-smoke.receipt" ubuntu:26.04 true
[[ ! -s "$receipt" ]]
if docker run --rm --platform linux/arm64 ubuntu:26.04 \
  bash -ceu 'command -v opi-command-that-must-not-exist'; then
    echo "Negative missing-command control unexpectedly passed" >&2
    exit 1
fi

echo "Functional ARM64 container checks: PASS"
