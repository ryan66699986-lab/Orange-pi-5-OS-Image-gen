say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
good() { printf '\033[1;32mOK: %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

require_host_cmds() {
    local c
    for c in docker git curl jq python3 openssl sha256sum file readelf tar unzip gzip xz sed awk grep find df tee sort tail timeout install cp mv chmod; do
        command -v "$c" >/dev/null 2>&1 || die "Missing host command: $c"
    done
}

git_net() {
    local duration="${GIT_NETWORK_TIMEOUT:-15m}"
    GIT_TERMINAL_PROMPT=0 timeout --kill-after=30s "$duration" \
        git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=120 "$@"
}

git_remote_ref() {
    local repo_url="$1" ref="$2" attempt out rc
    for attempt in 1 2 3 4; do
        set +e
        out="$(GIT_NETWORK_TIMEOUT=90s git_net ls-remote --refs "$repo_url" "$ref" 2>"$WORK/git-ls-remote.err")"; rc=$?
        set -e
        if (( rc == 0 )); then printf '%s\n' "$out"; return 0; fi
        warn "git ls-remote failed for ${repo_url} (${attempt}/4): $(tr '\n' ' ' < "$WORK/git-ls-remote.err")"
        sleep $((attempt * 2))
    done
    return 1
}

remote_tag_commit() {
    local repo_url="$1" tag="$2" out commit peeled
    out="$(git_remote_ref "$repo_url" "refs/tags/${tag}")" || return 1
    commit="$(awk 'NR==1 {print $1}' <<<"$out")"
    [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || return 1
    peeled="$(GIT_NETWORK_TIMEOUT=90s git_net ls-remote "$repo_url" "refs/tags/${tag}^{}" 2>/dev/null | awk 'NR==1 {print $1}')"
    if [[ "$peeled" =~ ^[0-9a-f]{40}$ ]]; then commit="$peeled"; fi
    printf '%s\n' "$commit"
}
require_github_tag() { local repo="$1" tag="$2" commit; commit="$(remote_tag_commit "https://github.com/${repo}.git" "$tag")" || die "Unable to verify pinned GitHub tag via Git transport: ${repo} ${tag}"; [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "Pinned GitHub tag does not exist: ${repo} ${tag}"; }
require_gitlab_tag() { local repo="$1" tag="$2" commit; commit="$(remote_tag_commit "https://gitlab.com/${repo}.git" "$tag")" || die "Unable to verify pinned GitLab tag via Git transport: ${repo} ${tag}"; [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "Pinned GitLab tag does not exist: ${repo} ${tag}"; }
require_github_commit() {
    local repo="$1" commit="$2" tmp
    [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "Invalid pinned GitHub commit syntax: ${repo} ${commit}"
    tmp="$(mktemp -d "$WORK/commit-check.XXXXXX")"; git -C "$tmp" init -q
    GIT_NETWORK_TIMEOUT=5m git_net -C "$tmp" fetch -q --depth=1 "https://github.com/${repo}.git" "$commit" || { rm -rf "$tmp"; die "Unable to fetch pinned GitHub commit via Git transport: ${repo} ${commit}"; }
    [[ "$(git -C "$tmp" rev-parse FETCH_HEAD)" == "$commit" ]] || { rm -rf "$tmp"; die "Pinned GitHub commit verification mismatch: ${repo} ${commit}"; }
    rm -rf "$tmp"
}
http_status(){ curl --retry 3 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 90 -L -sS -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true; }
head_status(){ curl --retry 3 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 90 -IL -sS -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true; }
github_content_exists() {
    local repo="$1" ref="$2" path="$3" url="https://raw.githubusercontent.com/${1}/${2}/${3}" status attempt
    for attempt in 1 2 3 4; do status="$(http_status "$url")"; case "$status" in 200) return 0;; 404) die "Expected source path missing: ${repo}@${ref}:${path}";; *) warn "Unable to verify source path ${repo}@${ref}:${path}; HTTP ${status:-000} (${attempt}/4)"; sleep $((attempt*2));; esac; done
    die "Source-layout verification unavailable after retries: ${repo}@${ref}:${path}"
}
require_url_contains() {
    local url="$1" regex="$2" label="$3" tmp attempt; tmp="$(mktemp "$WORK/source-check.XXXXXX")"
    for attempt in 1 2 3 4; do if curl --retry 2 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 90 -fsSL "$url" -o "$tmp"; then grep -Eq "$regex" "$tmp" && { rm -f "$tmp"; return 0; }; rm -f "$tmp"; die "Source compatibility check failed: ${label}"; fi; warn "Unable to fetch source compatibility file ${label} (${attempt}/4)"; sleep $((attempt*2)); done
    rm -f "$tmp"; die "Unable to fetch source compatibility file after retries: ${label}"
}
require_download_url() {
    local url="$1" label="$2" status attempt
    for attempt in 1 2 3 4; do status="$(curl --retry 2 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 90 -IL -sS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"; case "$status" in 200|206) return 0;; 404) die "Required release asset does not exist: ${label}";; *) warn "Unable to verify release asset ${label}; HTTP ${status:-000} (${attempt}/4)"; sleep $((attempt*2));; esac; done
    die "Required release asset could not be verified after retries: ${label}"
}
remote_branch_commit(){ local out; out="$(git_remote_ref "$1" "refs/heads/${2}")" || return 1; awk 'NR==1 {print $1}' <<<"$out"; }
download() {
    local url="$1" destination="$2" expected_sha="${3:-}"
    local key cached sidecar actual recorded tmp
    [[ -n "${DOWNLOAD_CACHE:-}" ]] || die "Persistent download cache path is unset"
    mkdir -p "$DOWNLOAD_CACHE" "$(dirname "$destination")"
    key="$(printf '%s' "$url" | sha256sum | awk '{print $1}')"
    cached="${DOWNLOAD_CACHE}/${key}"
    sidecar="${cached}.sha256"

    if [[ -s "$cached" && -s "$sidecar" ]]; then
        actual="$(sha_file "$cached")"
        recorded="$(awk 'NR==1 {print $1}' "$sidecar")"
        if [[ "$recorded" =~ ^[0-9a-f]{64}$ && "$actual" == "$recorded" && ( -z "$expected_sha" || "$actual" == "$expected_sha" ) ]]; then
            cp -- "$cached" "$destination"
            good "Verified download cache hit: $(basename "$destination")"
            return 0
        fi
        warn "Discarding invalid cached download: $(basename "$destination")"
        rm -f -- "$cached" "$sidecar"
    fi

    tmp="${cached}.part.$$"
    rm -f -- "$tmp"
    if ! curl --retry 5 --retry-delay 2 --retry-all-errors -fL "$url" -o "$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi
    actual="$(sha_file "$tmp")"
    if [[ -n "$expected_sha" && "$actual" != "$expected_sha" ]]; then
        rm -f -- "$tmp"
        die "Downloaded SHA-256 mismatch for $(basename "$destination") (expected ${expected_sha}, got ${actual})"
    fi
    chmod 0644 "$tmp"
    mv -f -- "$tmp" "$cached"
    printf '%s\n' "$actual" > "${sidecar}.tmp.$$"
    mv -f -- "${sidecar}.tmp.$$" "$sidecar"
    cp -- "$cached" "$destination"
}
sha_file(){ sha256sum "$1" | awk '{print $1}'; }
assert_aarch64_host_file(){ local d; d="$(file -b "$1")"; grep -Eqi 'ELF .*ARM aarch64|ELF .*aarch64' <<<"$d" || die "Expected AArch64 ELF but got: $1 :: $d"; }
remove_workdir() {
    local path="$1"; [[ -e "$path" || -L "$path" ]] || return 0
    if rm -rf -- "$path" 2>/dev/null && [[ ! -e "$path" && ! -L "$path" ]]; then return 0; fi
    if [[ -L "$path" || ! -d "$path" ]]; then rm -f -- "$path" 2>/dev/null || return 1; [[ ! -e "$path" && ! -L "$path" ]]; return; fi
    warn "Workspace has Docker-owned files; using root container cleanup"
    docker run --rm --platform linux/amd64 -v "$path:/workspace" ubuntu:26.04 bash -ceu 'find /workspace -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +' || return 1
    rmdir -- "$path" 2>/dev/null || true; [[ ! -e "$path" && ! -L "$path" ]]
}
