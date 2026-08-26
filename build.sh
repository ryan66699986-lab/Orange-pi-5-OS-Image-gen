#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${REPO_ROOT}/orangepi5pro-gaming"

# shellcheck disable=SC1091
source "${PROFILE_DIR}/profile.env"

BUILD_STARTED_SECONDS=$SECONDS
CURRENT_STAGE_NAME=""
CURRENT_STAGE_STARTED_SECONDS=$SECONDS
CURRENT_STAGE_RECORDED=1
TIMING_FLUSHED_COUNT=0
declare -a TIMING_ROWS=()

flush_timing_rows() {
    [[ -n "${TIMING_LOG:-}" && -d "${WORK:-/nonexistent}" ]] || return 0
    while (( TIMING_FLUSHED_COUNT < ${#TIMING_ROWS[@]} )); do
        printf '%b\n' "${TIMING_ROWS[$TIMING_FLUSHED_COUNT]}" >> "$TIMING_LOG" || return 0
        ((TIMING_FLUSHED_COUNT += 1))
    done
}

record_stage_timing() {
    local status="$1" elapsed
    elapsed=$((SECONDS - CURRENT_STAGE_STARTED_SECONDS))
    printf 'TIMING: scope=stage name=%s status=%s elapsed_seconds=%s\n' \
        "$CURRENT_STAGE_NAME" "$status" "$elapsed"
    TIMING_ROWS+=("stage\t${CURRENT_STAGE_NAME}\t${status}\t${elapsed}")
    flush_timing_rows
    CURRENT_STAGE_RECORDED=1
}

while IFS= read -r stage; do
    CURRENT_STAGE_NAME="$(basename "$stage" .sh)"
    CURRENT_STAGE_STARTED_SECONDS=$SECONDS
    CURRENT_STAGE_RECORDED=0
    # shellcheck disable=SC1090
    source "$stage"
    record_stage_timing "PASS"
    CURRENT_STAGE_NAME=""
done < <(find "${PROFILE_DIR}/stages" -maxdepth 1 -type f -name '*.sh' -print | sort)

TOTAL_ELAPSED=$((SECONDS - BUILD_STARTED_SECONDS))
printf 'TIMING: scope=build name=v%s status=PASS elapsed_seconds=%s\n' "$PROFILE_VERSION" "$TOTAL_ELAPSED"
TIMING_ROWS+=("build\tv${PROFILE_VERSION}\tPASS\t${TOTAL_ELAPSED}")
flush_timing_rows
if [[ -s "$TIMING_LOG" ]]; then
    cp -- "$TIMING_LOG" "${OUT}/${IMAGE_BASENAME}-STAGE-TIMINGS.tsv" || warn "Could not preserve stage timing report"
fi
