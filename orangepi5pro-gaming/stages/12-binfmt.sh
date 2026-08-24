say "ARM64 Docker execution"
if ! docker run --rm --platform linux/arm64 ubuntu:26.04 uname -m 2>/dev/null | grep -qx aarch64; then say "Installing host binfmt handler for ARM64"; docker run --privileged --rm tonistiigi/binfmt --install arm64; fi
docker run --rm --platform linux/arm64 ubuntu:26.04 uname -m | grep -qx aarch64 || die "linux/arm64 containers still cannot execute."
good "linux/arm64 containers execute through binfmt/QEMU"
