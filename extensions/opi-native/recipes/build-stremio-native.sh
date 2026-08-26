#!/usr/bin/env bash
set -Eeuo pipefail
source /arm64-common.sh
apt_prepare

apt-get install -y --no-install-recommends \
  build-essential pkg-config git curl ca-certificates \
  meson ninja-build python3 \
  libdrm-dev libudev-dev libssl-dev zlib1g-dev \
  libass-dev libplacebo-dev libjpeg-dev libuchardet-dev \
  libwayland-dev wayland-protocols libxkbcommon-dev \
  libegl1-mesa-dev libgl1-mesa-dev libvulkan-dev \
  libpulse-dev libpipewire-0.3-dev \
  libgtk-4-dev libadwaita-1-dev libwebkitgtk-6.0-dev libsoup-3.0-dev \
  libepoxy-dev gettext cargo rustc nodejs libglib2.0-bin

pkg-config --atleast-version=4.22 gtk4 || {
  echo "GTK4 < 4.22; cannot build Stremio v1.1.4" >&2; exit 1; }
pkg-config --atleast-version=1.9 libadwaita-1 || {
  echo "libadwaita < 1.9; cannot build Stremio v1.1.4" >&2; exit 1; }
pkg-config --atleast-version=2.52 webkitgtk-6.0 || {
  echo "WebKitGTK < 2.52; cannot build Stremio v1.1.4" >&2; exit 1; }
RUSTVER="$(rustc --version | awk '{print $2}')"
dpkg --compare-versions "$RUSTVER" ge 1.85 || {
  echo "Rust $RUSTVER is too old for edition 2024" >&2; exit 1; }
printf 'Stremio build ABI: GTK=%s Adwaita=%s WebKit=%s Rust=%s\n' \
  "$(pkg-config --modversion gtk4)" \
  "$(pkg-config --modversion libadwaita-1)" \
  "$(pkg-config --modversion webkitgtk-6.0)" \
  "$RUSTVER"

git init /ffmpeg
git -C /ffmpeg remote add origin "$V4L2_FFMPEG_REPO"
git_net -C /ffmpeg fetch --depth=1 origin "$V4L2_FFMPEG_COMMIT"
git -C /ffmpeg checkout --detach FETCH_HEAD
[[ "$(git -C /ffmpeg rev-parse HEAD)" == "$V4L2_FFMPEG_COMMIT" ]] || {
  echo "Kwiboo FFmpeg checkout does not match the resolved commit" >&2
  exit 1
}

cd /ffmpeg
./configure \
  --prefix=/opt/opi/media \
  --enable-shared \
  --disable-static \
  --disable-doc \
  --disable-debug \
  --enable-gpl \
  --enable-version3 \
  --enable-openssl \
  --enable-libdrm \
  --enable-libudev \
  --enable-v4l2-request
make -j"$JOBS"
make install

export PATH="/opt/opi/media/bin:$PATH"
export LD_LIBRARY_PATH="/opt/opi/media/lib:/opt/opi/media/lib64:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/opt/opi/media/lib/pkgconfig:/opt/opi/media/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

ffmpeg -hide_banner -hwaccels 2>&1 | grep -qi v4l2request || {
  echo "Custom FFmpeg was built without v4l2request" >&2
  exit 1
}

git init /mpv
git -C /mpv remote add origin https://github.com/mpv-player/mpv.git
git_net -C /mpv fetch --depth=1 origin "$MPV_COMMIT"
git -C /mpv checkout --detach FETCH_HEAD
git_net -C /mpv submodule update --init --recursive --depth=1
[[ "$(git -C /mpv rev-parse HEAD)" == "$MPV_COMMIT" ]] || {
  echo "mpv checkout does not match the resolved commit" >&2
  exit 1
}
meson setup /mpv/build /mpv \
  --prefix=/opt/opi/media \
  --libdir=lib \
  -Dlibmpv=true \
  -Dtests=false \
  -Dbuild-date=false
meson compile -C /mpv/build -j "$JOBS"
meson install -C /mpv/build

/opt/opi/media/bin/mpv --no-config --hwdec=help 2>&1 | grep -qi v4l2request || {
  echo "Custom mpv cannot see v4l2request" >&2
  exit 1
}
MPV_LIBDIR="$(pkg-config --variable=libdir mpv)"
[[ "$MPV_LIBDIR" == /opt/opi/media/lib ]] || {
  echo "Unexpected mpv pkg-config libdir: ${MPV_LIBDIR:-empty}" >&2
  exit 1
}
[[ -e "$MPV_LIBDIR/libmpv.so" ]] || {
  echo "libmpv linker symlink missing from $MPV_LIBDIR" >&2
  exit 1
}
pkg-config --libs mpv | grep -Fq -- '-L/opt/opi/media/lib' || {
  echo "mpv pkg-config metadata does not expose the dedicated library path" >&2
  pkg-config --libs mpv >&2
  exit 1
}
export LIBRARY_PATH="$MPV_LIBDIR:${LIBRARY_PATH:-}"

git init /stremio
git -C /stremio remote add origin https://github.com/Stremio/stremio-linux-shell.git
git_net -C /stremio fetch --depth=1 origin "$STREMIO_COMMIT"
git -C /stremio checkout --detach FETCH_HEAD
git_net -C /stremio submodule update --init --recursive --depth=1
[[ "$(git -C /stremio rev-parse HEAD)" == "$STREMIO_COMMIT" ]] || {
  echo "Stremio checkout does not match the resolved commit" >&2
  exit 1
}
cd /stremio
VIDEO_IMPL=/stremio/src/app/video/imp.rs
grep -Fq 'init.set_property("vo", "libmpv")?;' "$VIDEO_IMPL" || {
  echo "Pinned Stremio video initializer changed; refusing an unreviewed hwdec patch" >&2
  exit 1
}
sed -i '/init\.set_property("vo", "libmpv")?;/a\
            init.set_property("hwdec", "v4l2request-copy")?;\
            init.set_property("hwdec-codecs", "all")?;' "$VIDEO_IMPL"
[[ "$(grep -Fc 'init.set_property("hwdec", "v4l2request-copy")?;' "$VIDEO_IMPL")" -eq 1 ]] || {
  echo "Stremio hwdec policy was not applied exactly once" >&2
  exit 1
}
[[ "$(grep -Fc 'init.set_property("hwdec-codecs", "all")?;' "$VIDEO_IMPL")" -eq 1 ]] || {
  echo "Stremio hwdec codec policy was not applied exactly once" >&2
  exit 1
}
cargo build --release --locked
STREMIO_BIN=/stremio/target/release/stremio-linux-shell
[[ -x "$STREMIO_BIN" ]] || {
  echo "Native Stremio binary missing after cargo build" >&2
  exit 1
}
[[ -f /stremio/data/server.js ]] || {
  echo "Pinned Stremio source does not contain data/server.js" >&2
  exit 1
}
[[ -s /stremio/data/server.js ]] || {
  echo "Pinned Stremio data/server.js is empty" >&2
  exit 1
}
grep -aFq 'v4l2request-copy' "$STREMIO_BIN" || {
  echo "Built Stremio binary does not contain the mandatory hwdec policy" >&2
  exit 1
}

install -d \
  /out/rootfs/opt/opi/media \
  /out/rootfs/opt/stremio \
  /out/rootfs/usr/local/bin \
  /out/rootfs/usr/share/applications \
  /out/rootfs/usr/share/icons/hicolor/scalable/apps \
  /out/rootfs/usr/share/metainfo \
  /out/rootfs/usr/share/dbus-1/services \
  /out/rootfs/usr/share/glib-2.0/schemas \
  /out/rootfs/usr/share/licenses/stremio

cp -a /opt/opi/media/. /out/rootfs/opt/opi/media/
install -m755 "$STREMIO_BIN" /out/rootfs/opt/stremio/stremio
install -m644 /stremio/data/server.js /out/rootfs/opt/stremio/server.js
install -m644 /stremio/data/icons/com.stremio.Stremio.svg \
  /out/rootfs/usr/share/icons/hicolor/scalable/apps/com.stremio.Stremio.svg
install -m644 /stremio/data/com.stremio.Stremio.desktop \
  /out/rootfs/usr/share/applications/com.stremio.Stremio.desktop
sed -Ei 's/^Categories=.*/Categories=AudioVideo;Video;Player;/' \
  /out/rootfs/usr/share/applications/com.stremio.Stremio.desktop
grep -qx 'Categories=AudioVideo;Video;Player;' \
  /out/rootfs/usr/share/applications/com.stremio.Stremio.desktop || {
  echo "Stremio desktop categories were not normalized" >&2
  exit 1
}
install -m644 /stremio/data/com.stremio.Stremio.metainfo.xml \
  /out/rootfs/usr/share/metainfo/com.stremio.Stremio.metainfo.xml
install -m644 /stremio/data/com.stremio.Stremio.gschema.xml \
  /out/rootfs/usr/share/glib-2.0/schemas/com.stremio.Stremio.gschema.xml
install -m644 /stremio/LICENSE /out/rootfs/usr/share/licenses/stremio/LICENSE

cat > /out/rootfs/usr/share/dbus-1/services/com.stremio.Stremio.service <<'DBUS'
[D-BUS Service]
Name=com.stremio.Stremio
Exec=/usr/local/bin/stremio
DBUS

while IFS= read -r -d '' mo; do
  lang="$(basename "$(dirname "$(dirname "$mo")")")"
  install -d "/out/rootfs/usr/share/locale/$lang/LC_MESSAGES"
  install -m644 "$mo" "/out/rootfs/usr/share/locale/$lang/LC_MESSAGES/stremio.mo"
done < <(find /stremio/po -type f -name stremio.mo -print0 2>/dev/null)

cat > /tmp/opi-stremio-hwdec.c <<'SHIM'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>
#include <mpv/client.h>

static int (*real_set_property)(mpv_handle *, const char *, mpv_format, void *);
static int (*real_set_property_string)(mpv_handle *, const char *, const char *);
static int (*real_set_property_async)(mpv_handle *, uint64_t, const char *, mpv_format, void *);

static void resolve_symbols(void) {
    if (!real_set_property)
        real_set_property = dlsym(RTLD_NEXT, "mpv_set_property");
    if (!real_set_property_string)
        real_set_property_string = dlsym(RTLD_NEXT, "mpv_set_property_string");
    if (!real_set_property_async)
        real_set_property_async = dlsym(RTLD_NEXT, "mpv_set_property_async");
}

int mpv_set_property(mpv_handle *ctx, const char *name, mpv_format format, void *data) {
    resolve_symbols();
    if (!real_set_property)
        return MPV_ERROR_UNINITIALIZED;
    if (name && strcmp(name, "hwdec") == 0 && format == MPV_FORMAT_STRING) {
        char *forced = "v4l2request-copy";
        return real_set_property(ctx, name, format, &forced);
    }
    return real_set_property(ctx, name, format, data);
}

int mpv_set_property_string(mpv_handle *ctx, const char *name, const char *data) {
    resolve_symbols();
    if (!real_set_property_string)
        return MPV_ERROR_UNINITIALIZED;
    if (name && strcmp(name, "hwdec") == 0)
        return real_set_property_string(ctx, name, "v4l2request-copy");
    return real_set_property_string(ctx, name, data);
}

int mpv_set_property_async(mpv_handle *ctx, uint64_t reply_userdata,
                           const char *name, mpv_format format, void *data) {
    resolve_symbols();
    if (!real_set_property_async)
        return MPV_ERROR_UNINITIALIZED;
    if (name && strcmp(name, "hwdec") == 0 && format == MPV_FORMAT_STRING) {
        char *forced = "v4l2request-copy";
        return real_set_property_async(ctx, reply_userdata, name, format, &forced);
    }
    return real_set_property_async(ctx, reply_userdata, name, format, data);
}
SHIM

cc -shared -fPIC -O2 -Wall -Wextra \
  -I/opt/opi/media/include \
  -o /out/rootfs/opt/stremio/libopi-stremio-hwdec.so \
  /tmp/opi-stremio-hwdec.c -ldl

cat > /out/rootfs/usr/local/bin/stremio <<'WRAP'
#!/usr/bin/env bash
set -Eeuo pipefail
export PATH="/opt/opi/media/bin:/usr/local/bin:/usr/bin:/bin"
export LD_LIBRARY_PATH="/opt/opi/media/lib:/opt/opi/media/lib64:${LD_LIBRARY_PATH:-}"
export LD_PRELOAD="/opt/stremio/libopi-stremio-hwdec.so${LD_PRELOAD:+:$LD_PRELOAD}"
export SERVER_PATH=/opt/stremio/server.js
export GDK_BACKEND=wayland,x11
export MOZ_ENABLE_WAYLAND=1
export LC_NUMERIC=C
export RUST_LOG="${RUST_LOG:-warn,vd=debug}"
mkdir -p "$HOME/.local/state/opi"
exec /opt/stremio/stremio "$@" \
  2> >(tee -a "$HOME/.local/state/opi/stremio.log" >&2)
WRAP

cat > /out/rootfs/usr/local/bin/mpv-v4l2request <<'WRAP'
#!/usr/bin/env bash
export LD_LIBRARY_PATH="/opt/opi/media/lib:/opt/opi/media/lib64:${LD_LIBRARY_PATH:-}"
exec /opt/opi/media/bin/mpv "$@"
WRAP

cat > /out/rootfs/usr/local/bin/ffmpeg-v4l2request <<'WRAP'
#!/usr/bin/env bash
export LD_LIBRARY_PATH="/opt/opi/media/lib:/opt/opi/media/lib64:${LD_LIBRARY_PATH:-}"
exec /opt/opi/media/bin/ffmpeg "$@"
WRAP

chmod 0755 \
  /out/rootfs/usr/local/bin/stremio \
  /out/rootfs/usr/local/bin/mpv-v4l2request \
  /out/rootfs/usr/local/bin/ffmpeg-v4l2request

assert_aarch64_tree /out/rootfs/opt/opi/media
for f in \
  /out/rootfs/opt/stremio/stremio \
  /out/rootfs/opt/stremio/libopi-stremio-hwdec.so; do
  DESC="$(file -b "$f")"
  grep -Eqi 'ARM aarch64|aarch64' <<<"$DESC" || {
    echo "Stremio artifact is not AArch64: $f :: $DESC" >&2
    exit 1
  }
done

collect_runtime_packages /out/rootfs/opt/opi/media /out/media-runtime.txt
collect_runtime_packages /out/rootfs/opt/stremio /out/stremio-runtime.txt
cat /out/media-runtime.txt /out/stremio-runtime.txt > /out/runtime-packages.txt
cat >> /out/runtime-packages.txt <<'RUNTIME'
nodejs
glib-networking
libglib2.0-bin
RUNTIME
sort -u -o /out/runtime-packages.txt /out/runtime-packages.txt

git -C /ffmpeg rev-parse HEAD > /out/ffmpeg.commit
git -C /mpv rev-parse HEAD > /out/mpv.commit
git -C /stremio rev-parse HEAD > /out/stremio.commit
