say "Stremio ARM64 ABI/toolchain preflight"
grep -Fq -- '--enable-version3' "$PROFILE_DIR/recipes/build-stremio-native.sh" || die "Stremio FFmpeg recipe lacks the OpenSSL 3 license-compatibility flag"
grep -Fq 'init.set_property("hwdec", "v4l2request-copy")?;' "$PROFILE_DIR/recipes/build-stremio-native.sh" || die "Stremio recipe lacks the embedded libmpv V4L2 Request policy"
docker run --rm --platform linux/arm64 ubuntu:26.04 bash -ceu '
  export DEBIAN_FRONTEND=noninteractive
  sed -Ei "s/^Components:.*/Components: main restricted universe multiverse/" /etc/apt/sources.list.d/ubuntu.sources
  apt-get update >/dev/null
  apt-get install -y --no-install-recommends pkg-config libssl-dev libgtk-4-dev libadwaita-1-dev libwebkitgtk-6.0-dev rustc cargo >/dev/null
  pkg-config --atleast-version=4.22 gtk4; pkg-config --atleast-version=1.9 libadwaita-1; pkg-config --atleast-version=2.52 webkitgtk-6.0
  rustver="$(rustc --version | awk "{print \$2}")"; dpkg --compare-versions "$rustver" ge 1.85
  printf "OpenSSL=%s GTK=%s Adwaita=%s WebKitGTK=%s rustc=%s\n" "$(pkg-config --modversion openssl)" "$(pkg-config --modversion gtk4)" "$(pkg-config --modversion libadwaita-1)" "$(pkg-config --modversion webkitgtk-6.0)" "$rustver"
'
good "Stremio ARM64 ABI/toolchain requirements satisfied"
