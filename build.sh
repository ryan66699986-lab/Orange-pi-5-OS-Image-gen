#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${REPO_ROOT}/orangepi5pro-gaming"

# shellcheck disable=SC1091
source "${PROFILE_DIR}/profile.env"

while IFS= read -r stage; do
    # shellcheck disable=SC1090
    source "$stage"
done < <(find "${PROFILE_DIR}/stages" -maxdepth 1 -type f -name '*.sh' -print | sort)
