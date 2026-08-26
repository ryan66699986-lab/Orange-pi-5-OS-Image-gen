#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt_prepare() {
    if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
        sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' \
            /etc/apt/sources.list.d/ubuntu.sources
    fi
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates git curl file binutils ccache
    for cmd in git curl file readelf ccache; do
        command -v "$cmd" >/dev/null 2>&1 || {
            echo "ARM64 recipe environment lacks command after installation: $cmd" >&2
            return 1
        }
    done
    export PATH="/usr/lib/ccache:${PATH}"
    ccache --show-config | grep -Eq '^\([^)]*\)[[:space:]]+compiler_check = content$' || {
        echo "Native compiler cache is not using content verification" >&2
        return 1
    }
}

git_net() {
    GIT_TERMINAL_PROMPT=0 timeout --kill-after=30s 15m \
        git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=120 "$@"
}

assert_aarch64_tree() {
    local root="$1" found=0 bad=0 f desc
    while IFS= read -r -d '' f; do
        desc="$(file -b "$f" 2>/dev/null || true)"
        if [[ "$desc" == ELF* ]]; then
            found=1
            if ! grep -Eqi 'ARM aarch64|aarch64' <<<"$desc"; then
                echo "NON-AARCH64 ELF: $f :: $desc" >&2
                bad=1
            fi
        fi
    done < <(find "$root" -type f -print0)
    (( bad == 0 )) || return 1
    (( found == 1 )) || { echo "No ELF found in $root" >&2; return 1; }
}

elf_has_needed() {
    local path="$1"
    file -Lb "$path" 2>/dev/null | grep -q '^ELF' || return 1
    readelf -d "$path" 2>/dev/null | grep -q '(NEEDED)'
}

checked_ldd() {
    local path="$1" library_path="${2:-}" output
    if ! output="$(LD_LIBRARY_PATH="$library_path" ldd "$path" 2>&1)"; then
        echo "ldd failed for dynamic ELF: $path" >&2
        printf '%s\n' "$output" >&2
        return 1
    fi
    if grep -q 'not found' <<<"$output"; then
        echo "Unresolved shared library in dynamic ELF: $path" >&2
        printf '%s\n' "$output" >&2
        return 1
    fi
    printf '%s\n' "$output"
}

collect_runtime_packages() {
    local root="$1" out="$2"
    local libs pkgs unmapped f lib owner canonical linkage
    libs="$(mktemp)"
    pkgs="$(mktemp)"
    unmapped="$(mktemp)"
    : > "$libs"
    : > "$pkgs"
    : > "$unmapped"

    while IFS= read -r -d '' f; do
        elf_has_needed "$f" || continue
        if ! linkage="$(checked_ldd "$f" "${RUNTIME_LIBRARY_PATH:-}")"; then
            rm -f "$libs" "$pkgs" "$unmapped"
            return 1
        fi
        awk '/=> \// {print $3} /^\// {print $1}' <<<"$linkage" >> "$libs"
    done < <(find "$root" -type f -print0)

    sort -u "$libs" | while read -r lib; do
        [[ -e "$lib" ]] || continue
        canonical=""
        owner="$(dpkg-query -S "$lib" 2>/dev/null | head -n1 | awk -F': ' '{pkg=$1; sub(/:[^:]+$/, "", pkg); print pkg}' || true)"
        if [[ -z "$owner" ]]; then
            # ldd may report /lib/... on a merged-/usr system while dpkg owns
            # the canonical /usr/lib/... pathname. Query both representations.
            canonical="$(readlink -f "$lib" 2>/dev/null || true)"
            [[ -n "$canonical" ]] && owner="$(dpkg-query -S "$canonical" 2>/dev/null | head -n1 | awk -F': ' '{pkg=$1; sub(/:[^:]+$/, "", pkg); print pkg}' || true)"
        fi
        if [[ -n "$owner" ]]; then
            printf '%s\n' "$owner"
        elif [[ "$lib" == /lib/* || "$lib" == /usr/lib/* || "$canonical" == /lib/* || "$canonical" == /usr/lib/* ]]; then
            printf '%s -> %s\n' "$lib" "${canonical:-<unresolved>}" >> "$unmapped"
        fi
    done | sed '/^$/d' | sort -u > "$pkgs"

    if [[ -s "$unmapped" ]]; then
        echo "Resolved system libraries without a dpkg owner under $root:" >&2
        cat "$unmapped" >&2
        rm -f "$libs" "$pkgs" "$unmapped"
        return 1
    fi

    cp "$pkgs" "$out"
    rm -f "$libs" "$pkgs" "$unmapped"
}
