#!/usr/bin/env bash
set -Eeuo pipefail

readonly USERPATCHES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ARMBIAN_DIR="$(cd -- "${USERPATCHES_DIR}/.." && pwd)"
readonly SOURCE_LOCK="${USERPATCHES_DIR}/extensions/opi-native/sources.env"

set -a
source "${SOURCE_LOCK}"
set +a

[[ -x "${ARMBIAN_DIR}/compile.sh" ]] || {
    echo "Place this repository at <armbian-build>/userpatches, then run userpatches/build.sh." >&2
    exit 1
}
[[ -d "${ARMBIAN_DIR}/.git" ]] || {
    echo "The parent directory is not an Armbian Git checkout." >&2
    exit 1
}

if ! git -C "${ARMBIAN_DIR}" cat-file -e "${ARMBIAN_COMMIT}^{commit}" 2>/dev/null; then
    git -C "${ARMBIAN_DIR}" fetch --no-tags origin "${ARMBIAN_COMMIT}"
fi

git -C "${ARMBIAN_DIR}" checkout --detach "${ARMBIAN_COMMIT}"
exec "${ARMBIAN_DIR}/compile.sh" build opi5pro "$@"
