#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt_prepare() {
    if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
        sed -Ei 's/^Components:.*/Components: main restricted universe multiverse/' \
            /etc/apt/sources.list.d/ubuntu.sources
    fi
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates git curl file binutils
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

collect_runtime_packages() {
    local root="$1" out="$2"
    local libs pkgs f desc lib
    libs="$(mktemp)"
    pkgs="$(mktemp)"
    : > "$libs"
    : > "$pkgs"

    while IFS= read -r -d '' f; do
        desc="$(file -b "$f" 2>/dev/null || true)"
        [[ "$desc" == ELF* ]] || continue
        ldd "$f" 2>/dev/null |
          awk '/=> \// {print $3} /^\// {print $1}' >> "$libs" || true
    done < <(find "$root" -type f -print0)

    sort -u "$libs" | while read -r lib; do
        [[ -e "$lib" ]] || continue
        dpkg-query -S "$lib" 2>/dev/null | head -n1 | cut -d: -f1 || true
    done | sed '/^$/d' | sort -u > "$pkgs"

    cp "$pkgs" "$out"
    rm -f "$libs" "$pkgs"
}
