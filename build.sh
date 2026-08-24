#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${REPO_ROOT}/orangepi5pro-gaming"

# shellcheck disable=SC1091
source "${PROFILE_DIR}/profile.env"

for stage in \
    00-common.sh \
    10-preflight.sh \
    20-armbian.sh \
    30-artifacts.sh \
    40-rootfs.sh \
    50-image-and-qa.sh
do
    # shellcheck disable=SC1090
    source "${PROFILE_DIR}/stages/${stage}"
done
