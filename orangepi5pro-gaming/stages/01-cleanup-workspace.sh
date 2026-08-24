SUCCESS=0
cleanup() {
    local rc=$?
    if (( SUCCESS == 1 )); then remove_workdir "$WORK" && good "Temporary V3.10 workspace removed" || warn "Image succeeded but temporary workspace could not be fully removed: $WORK"; exit 0; fi
    mkdir -p "$OUT"; local stamp diag; stamp="$(date +%Y%m%d-%H%M%S)"; diag="${OUT}/failed-v3.10-${stamp}"; mkdir -p "$diag"
    [[ -f "$LOG" ]] && cp -a "$LOG" "$diag/" || true; [[ -f "$LOCK" ]] && cp -a "$LOCK" "$diag/" || true; [[ -d "$SCRIPTS" ]] && cp -a "$SCRIPTS" "$diag/" || true
    if [[ -d "$ARMBIAN/output/logs" ]]; then mkdir -p "$diag/armbian-logs"; find "$ARMBIAN/output/logs" -maxdepth 1 -type f -print0 2>/dev/null | xargs -0 -r -I{} cp -a "{}" "$diag/armbian-logs/" || true; fi
    printf '\nBUILD FAILED. Diagnostic bundle:\n  %s\n' "$diag" >&2
    if remove_workdir "$WORK"; then printf 'The failed V3.10 workspace was completely deleted. The next attempt will be fresh.\n' >&2; else printf 'ERROR: failed V3.10 workspace could not be deleted:\n  %s\n' "$WORK" >&2; rc=1; fi
    exit "$rc"
}
trap cleanup EXIT INT TERM
require_host_cmds
docker info >/dev/null 2>&1 || die "Docker daemon is not accessible to this user."
case "$(uname -m)" in x86_64|amd64) ;; *) die "This builder is intended for the x86_64 host PC." ;; esac
mkdir -p "$OUT"
remove_workdir "$WORK" || die "Could not fully delete prior V3.10 workspace: $WORK"
[[ ! -e "$WORK" ]] || die "Fresh-start invariant failed: $WORK still exists"
mkdir -p "$WORK" "$ART" "$SCRIPTS" "$DOWNLOADS" "$OVERLAY"
exec > >(tee -a "$LOG") 2>&1
