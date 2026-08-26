#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh

[[ "$(dpkg --print-architecture)" == arm64 ]]
apt_prepare
for cmd in git curl file readelf ccache; do
    command -v "$cmd" >/dev/null
done

while IFS='|' read -r name packages; do
    [[ -n "$name" ]] || continue
    read -r -a group <<<"$packages"
    apt-get -s install -y --no-install-recommends "${group[@]}" >/dev/null || {
        echo "Isolated ARM64 dependency group is not solvable: $name" >&2
        exit 1
    }
done < /build-package-groups.txt

{
    echo 'schema=opi-container-smoke-v1'
    echo 'architecture=arm64'
    echo 'common_tools=PASS'
    echo 'isolated_groups=PASS'
    echo 'result=PASS'
} > /container-smoke.receipt
