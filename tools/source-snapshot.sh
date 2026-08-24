#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/out}"
mkdir -p "$OUT"
tar -C "$ROOT" \
  --exclude='.git' --exclude='out' \
  -czf "$OUT/Orange-pi-5-OS-Image-gen-source.tar.gz" .
sha256sum "$OUT/Orange-pi-5-OS-Image-gen-source.tar.gz"
