SUCCESS=0
cleanup() {
    local rc=$?
    if [[ -n "${CURRENT_STAGE_NAME:-}" && "${CURRENT_STAGE_RECORDED:-0}" == 0 ]]; then
        record_stage_timing "FAIL" || true
    fi
    if (( SUCCESS == 1 )); then remove_workdir "$WORK" && good "Temporary V${PROFILE_VERSION} workspace removed" || warn "Image succeeded but temporary workspace could not be fully removed: $WORK"; exit 0; fi
    mkdir -p "$OUT"; local stamp diag; stamp="$(date +%Y%m%d-%H%M%S)"; diag="${OUT}/failed-v${PROFILE_VERSION}-${stamp}"; mkdir -p "$diag"
    [[ -f "$LOG" ]] && cp -a "$LOG" "$diag/" || true; [[ -f "$LOCK" ]] && cp -a "$LOCK" "$diag/" || true; [[ -f "$TIMING_LOG" ]] && cp -a "$TIMING_LOG" "$diag/" || true; [[ -d "$SCRIPTS" ]] && cp -a "$SCRIPTS" "$diag/" || true
    if [[ -d "$ARMBIAN/output/logs" ]]; then mkdir -p "$diag/armbian-logs"; find "$ARMBIAN/output/logs" -maxdepth 1 -type f -print0 2>/dev/null | xargs -0 -r -I{} cp -a "{}" "$diag/armbian-logs/" || true; fi
    printf '\nBUILD FAILED. Diagnostic bundle:\n  %s\n' "$diag" >&2
    if remove_workdir "$WORK"; then printf 'The failed V%s workspace was completely deleted. The next attempt will be fresh.\n' "$PROFILE_VERSION" >&2; else printf 'ERROR: failed V%s workspace could not be deleted:\n  %s\n' "$PROFILE_VERSION" "$WORK" >&2; rc=1; fi
    exit "$rc"
}
trap cleanup EXIT INT TERM
require_host_cmds
docker info >/dev/null 2>&1 || die "Docker daemon is not accessible to this user."
case "$(uname -m)" in x86_64|amd64) ;; *) die "This builder is intended for the x86_64 host PC." ;; esac
mkdir -p "$OUT"
[[ "$CACHE_ROOT" == /* ]] || die "Cache root must be an absolute path: $CACHE_ROOT"
CACHE_ROOT="$(python3 - "$CACHE_ROOT" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
)"
DOWNLOAD_CACHE="${CACHE_ROOT}/downloads"
COMPILER_CACHE="${CACHE_ROOT}/compiler"
case "$CACHE_ROOT" in /|"$HOME"|"$REPO_ROOT"|"$REPO_ROOT"/*|"$WORK"|"$WORK"/*|"$OUT"|"$OUT"/*) die "Unsafe cache root: $CACHE_ROOT";; esac
mkdir -p "$DOWNLOAD_CACHE" "$COMPILER_CACHE/ccache" "$COMPILER_CACHE/tooling"
[[ -d "$CACHE_ROOT" && -w "$CACHE_ROOT" ]] || die "Persistent cache root is not writable: $CACHE_ROOT"
remove_workdir "$WORK" || die "Could not fully delete prior V${PROFILE_VERSION} workspace: $WORK"
[[ ! -e "$WORK" ]] || die "Fresh-start invariant failed: $WORK still exists"
mkdir -p "$WORK" "$ART" "$SCRIPTS" "$DOWNLOADS" "$OVERLAY"
printf 'scope\tname\tstatus\telapsed_seconds\n' > "$TIMING_LOG"
exec > >(tee -a "$LOG") 2>&1
