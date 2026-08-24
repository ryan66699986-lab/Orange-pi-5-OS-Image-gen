say "Resolute ARM64 package preflight"
docker run --rm --platform linux/arm64 -v "$WORK/required-packages.txt:/required-packages.txt:ro" ubuntu:26.04 bash -lc '
  set -Eeuo pipefail; export DEBIAN_FRONTEND=noninteractive
  sed -Ei "s/^Components:.*/Components: main restricted universe multiverse/" /etc/apt/sources.list.d/ubuntu.sources
  apt-get update >/dev/null; mapfile -t pkgs < /required-packages.txt; missing=()
  for p in "${pkgs[@]}"; do apt-get -s install "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if ((${#missing[@]})); then printf "Required Resolute ARM64 packages without an installable solution:\n" >&2; printf "  - %s\n" "${missing[@]}" >&2; exit 1; fi
  apt-get -s install "${pkgs[@]}" >/dev/null
'
good "All required Ubuntu Resolute ARM64 packages resolve"
say "Generating offline H.264/HEVC/HEVC Main10/VP9/AV1 hardware-decode probes"
mkdir -p "$WORK/probe"
docker run --rm --platform linux/amd64 -v "$WORK/probe:/out" ubuntu:26.04 bash -ceu '
  export DEBIAN_FRONTEND=noninteractive; apt-get update >/dev/null; apt-get install -y --no-install-recommends ffmpeg >/dev/null
  for enc in libx264 libx265 libvpx-vp9 libaom-av1; do ffmpeg -hide_banner -loglevel error -encoders | grep -q "$enc" || { echo "Probe encoder unavailable: $enc" >&2; exit 1; }; done
  ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=640x360:rate=30" -t 2 -pix_fmt yuv420p -c:v libx264 -preset ultrafast -movflags +faststart /out/h264-hwprobe.mp4
  ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=640x360:rate=30" -t 2 -pix_fmt yuv420p -c:v libx265 -preset ultrafast -x265-params log-level=error -movflags +faststart /out/hevc-hwprobe.mp4
  ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=640x360:rate=30" -t 2 -pix_fmt yuv420p10le -c:v libx265 -preset ultrafast -x265-params log-level=error -movflags +faststart /out/hevc-main10-hwprobe.mp4
  ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p -c:v libx264 -preset ultrafast -movflags +faststart /out/h264-4k-hwprobe.mp4
  ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -c:v libx265 -preset ultrafast -x265-params "log-level=error:hdr10=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:max-cll=1000,400" -movflags +faststart /out/hevc-main10-4k-hdr10-hwprobe.mp4
  ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -row-mt 1 /out/vp9-4k-hwprobe.webm
  ffmpeg -hide_banner -loglevel error -f lavfi -i "testsrc2=size=3840x2160:rate=24" -t 1 -pix_fmt yuv420p -c:v libaom-av1 -cpu-used 8 -row-mt 1 -tiles 2x2 -strict experimental /out/av1-4k-hwprobe.mkv
  for f in /out/h264-hwprobe.mp4 /out/hevc-hwprobe.mp4 /out/hevc-main10-hwprobe.mp4 /out/h264-4k-hwprobe.mp4 /out/hevc-main10-4k-hdr10-hwprobe.mp4 /out/vp9-4k-hwprobe.webm /out/av1-4k-hwprobe.mkv; do test -s "$f" || { echo "Empty hardware probe: $f" >&2; exit 1; }; done
  test "$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of default=nw=1:nk=1 /out/hevc-main10-hwprobe.mp4)" = "Main 10"
  for f in /out/h264-4k-hwprobe.mp4 /out/hevc-main10-4k-hdr10-hwprobe.mp4 /out/vp9-4k-hwprobe.webm /out/av1-4k-hwprobe.mkv; do test "$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$f")" = 3840; test "$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$f")" = 2160; done
  test "$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of default=nw=1:nk=1 /out/hevc-main10-4k-hdr10-hwprobe.mp4)" = "Main 10"
  test "$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=nw=1:nk=1 /out/hevc-main10-4k-hdr10-hwprobe.mp4)" = "smpte2084"
'
mkdir -p "$USERPATCHES_DIR/overlay"
printf '%s\n' "$PI_PASS_HASH" > "$WORK/user-password.hash"; unset PI_PASS_HASH
docker run --rm --platform linux/amd64 -v "$OVERLAY:/src:ro" -v "$USERPATCHES_DIR/overlay:/dst" -v "$LOCK:/meta/versions.lock.json:ro" -v "$WORK/required-packages.txt:/meta/required-packages.txt:ro" -v "$WORK/user-password.hash:/meta/user-password.hash:ro" -v "$WORK/probe:/probes:ro" ubuntu:26.04 bash -ceu '
  cp -a /src/. /dst/; install -d -m0755 /dst/opt/opi-build-meta
  install -m0644 /meta/versions.lock.json /dst/opt/opi-build-meta/versions.lock.json
  install -m0644 /meta/required-packages.txt /dst/opt/opi-build-meta/required-packages.txt
  install -m0600 /meta/user-password.hash /dst/opt/opi-build-meta/user-password.hash
  install -m0644 /probes/* /dst/opt/opi-build-meta/
'
rm -f "$WORK/user-password.hash"
cat "$PROFILE_DIR"/rootfs/customize.d/*.sh.inc > "$USERPATCHES_DIR/customize-image.sh"
chmod 0755 "$USERPATCHES_DIR/customize-image.sh"
