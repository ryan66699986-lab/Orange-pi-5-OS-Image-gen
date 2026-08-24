say "Early Ubuntu Resolute ARM64 package preflight"
docker run --rm --platform linux/arm64 -v "$WORK/required-packages.base.txt:/base.txt:ro" -v "$WORK/build-package-groups.txt:/groups.txt:ro" ubuntu:26.04 bash -ceu '
  export DEBIAN_FRONTEND=noninteractive
  sed -Ei "s/^Components:.*/Components: main restricted universe multiverse/" /etc/apt/sources.list.d/ubuntu.sources
  apt-get update >/dev/null
  mapfile -t base < /base.txt
  apt-get -s install "${base[@]}" >/dev/null || { echo "Base runtime package set is not solvable on Resolute ARM64" >&2; for p in "${base[@]}"; do apt-get -s install "$p" >/dev/null 2>&1 || echo "  missing/unsatisfied: $p" >&2; done; exit 1; }
  while IFS="|" read -r name packages; do [[ -n "$name" ]] || continue; read -r -a pkgs <<<"$packages"; if ! apt-get -s install "${pkgs[@]}" >/dev/null 2>&1; then echo "Build dependency group is not solvable: $name" >&2; for p in "${pkgs[@]}"; do apt-get -s install "$p" >/dev/null 2>&1 || echo "  missing/unsatisfied: $p" >&2; done; exit 1; fi; done < /groups.txt
'
good "Base runtime and every source-build dependency group resolve on ARM64"
