log "Hardware decode validation helper"
cat > /usr/local/bin/opi-stremio-hwcheck <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
mpv=/opt/opi/media/bin/mpv
ff=/opt/opi/media/bin/ffmpeg
visible=0
if [[ "${1:-}" == --visible ]]; then visible=1; shift; fi
if (($#)); then echo "Usage: opi-stremio-hwcheck [--visible]" >&2; exit 2; fi
export LD_LIBRARY_PATH="/opt/opi/media/lib:/opt/opi/media/lib64:${LD_LIBRARY_PATH:-}"
[[ -x "$mpv" && -x "$ff" ]] || { echo "FAIL: dedicated V4L2-request mpv/FFmpeg stack missing"; exit 1; }
"$ff" -hide_banner -hwaccels 2>&1 | grep -qi v4l2request || { echo "FAIL: custom FFmpeg does not expose v4l2request"; exit 1; }
test_one() {
  local codec="$1" file="$2" log
  local -a video_args=(--vo=null)
  ((visible)) && video_args=(--fs --vo=gpu-next,gpu)
  [[ -s "$file" ]] || { echo "FAIL: $codec hardware-decode probe is missing: $file"; return 1; }
  log="$(mktemp)"
  if "$mpv" --no-config "${video_args[@]}" --ao=null --hwdec=v4l2request-copy --hwdec-codecs=all --frames=30 --msg-level=all=warn,vd=debug "$file" >"$log" 2>&1 && grep -Eqi 'Using hardware decoding.*v4l2request-copy' "$log"; then
    echo "PASS: $codec decoded through v4l2request-copy"; rm -f "$log"; return 0
  fi
  echo "FAIL: $codec did not use v4l2request-copy"; cat "$log"; rm -f "$log"; return 1
}
test_one H264 /opt/opi-build-meta/h264-hwprobe.mp4
test_one HEVC /opt/opi-build-meta/hevc-hwprobe.mp4
test_one HEVC-Main10 /opt/opi-build-meta/hevc-main10-hwprobe.mp4
test_one H264-4K /opt/opi-build-meta/h264-4k-hwprobe.mp4
test_one HEVC-Main10-4K-HDR10 /opt/opi-build-meta/hevc-main10-4k-hdr10-hwprobe.mp4
test_one VP9-4K /opt/opi-build-meta/vp9-4k-hwprobe.webm
test_one AV1-4K /opt/opi-build-meta/av1-4k-hwprobe.mkv
echo "PASS: RK3588 H.264 + HEVC + Main10/HDR10 + VP9 + AV1 hardware-decode gate"
EOF
chmod 0755 /usr/local/bin/opi-stremio-hwcheck
cat > /usr/local/bin/opi-stremio-session-check <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
log="${XDG_STATE_HOME:-$HOME/.local/state}/opi/stremio.log"
[[ -s "$log" ]] || {
  echo "FAIL: no Stremio playback log yet. Play H.264 and HEVC video in Stremio first: $log"
  exit 1
}
if grep -Eqi 'Using hardware decoding.*v4l2request-copy' "$log"; then
  echo "PASS: Stremio's embedded libmpv used v4l2request-copy"
  exit 0
fi
echo "FAIL: Stremio playback log has no v4l2request-copy hardware-decode evidence: $log"
exit 1
EOF
chmod 0755 /usr/local/bin/opi-stremio-session-check
cat > /usr/local/bin/opi-moonlight-hwcheck <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
bin=/opt/opi/apps/moonlight/moonlight-qt
cfg="$HOME/.config/Moonlight Game Streaming Project/Moonlight.conf"
export LD_LIBRARY_PATH="/opt/opi/media/lib:${LD_LIBRARY_PATH:-}"
[[ -x "$bin" ]] || { echo "FAIL: Moonlight executable missing: $bin"; exit 1; }
[[ -r "$cfg" ]] || { echo "FAIL: Moonlight hardware policy missing: $cfg"; exit 1; }
grep -qx 'videodec=1' "$cfg" || { echo "FAIL: Moonlight is not configured to force hardware decode"; exit 1; }
for key in width height fps; do
  value="$(sed -n "s/^${key}=//p" "$cfg" | tail -n1)"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo "FAIL: Moonlight ${key} is not a positive integer"; exit 1; }
done
/opt/opi/media/bin/ffmpeg -hide_banner -hwaccels 2>&1 | grep -qi v4l2request || { echo "FAIL: dedicated FFmpeg lacks v4l2request"; exit 1; }
ldd "$bin" > /tmp/opi-moonlight-ldd.txt
! grep -q 'not found' /tmp/opi-moonlight-ldd.txt || { cat /tmp/opi-moonlight-ldd.txt; echo "FAIL: Moonlight has unresolved libraries"; exit 1; }
for lib in libavcodec libavutil libswscale; do
  grep -Eq "${lib}\\.so[^ ]*[[:space:]]+=>[[:space:]]+/opt/opi/media/lib/" /tmp/opi-moonlight-ldd.txt || { cat /tmp/opi-moonlight-ldd.txt; echo "FAIL: Moonlight does not use project $lib"; exit 1; }
done
echo "PASS: Moonlight is forced to hardware decode and linked to the V4L2 Request media stack"
EOF
chmod 0755 /usr/local/bin/opi-moonlight-hwcheck
cat > /usr/local/bin/opi-moonlight-session-check <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
state_log="${XDG_STATE_HOME:-$HOME/.local/state}/opi/moonlight.log"
display_env="${XDG_STATE_HOME:-$HOME/.local/state}/opi/moonlight-display.env"
[[ -r "$display_env" ]] || { echo "FAIL: no display policy record. Launch Moonlight once first: $display_env"; exit 1; }
# shellcheck disable=SC1090
source "$display_env"
for value in "${EXPECTED_WIDTH:-}" "${EXPECTED_HEIGHT:-}" "${EXPECTED_FPS:-}"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo "FAIL: invalid Moonlight display policy record"; exit 1; }
done
logs=()
[[ -s "$state_log" ]] && logs+=("$state_log")
while IFS= read -r -d '' f; do logs+=("$f"); done < <(find /tmp -maxdepth 1 -type f -name 'Moonlight-*.log' -print0 2>/dev/null)
((${#logs[@]})) || { echo "FAIL: no Moonlight log yet. Complete a stream at the detected display mode first."; exit 1; }
grep -Ehi 'Video stream is|FFmpeg-based .*video decoder chosen|missing hardware|force hardware' "${logs[@]}" > /tmp/opi-moonlight-evidence.txt || true
grep -Eqi "Video stream is ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}x" /tmp/opi-moonlight-evidence.txt || { cat /tmp/opi-moonlight-evidence.txt; echo "FAIL: no completed ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT} Moonlight stream evidence"; exit 1; }
grep -Eqi 'FFmpeg-based hardware-accelerated video decoder chosen' /tmp/opi-moonlight-evidence.txt || { cat /tmp/opi-moonlight-evidence.txt; echo "FAIL: no Moonlight hardware-decoder evidence"; exit 1; }
! grep -Eqi 'missing hardware|force hardware.*(cannot|missing|failed)' /tmp/opi-moonlight-evidence.txt || { cat /tmp/opi-moonlight-evidence.txt; echo "FAIL: Moonlight logged a hardware-decode failure"; exit 1; }
echo "PASS: Moonlight completed a ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT} hardware-decoded stream (HDR detected: ${HDR_DETECTED:-unknown})"
EOF
chmod 0755 /usr/local/bin/opi-moonlight-session-check
cat > /usr/local/bin/opi-controller-check <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
found=0
while IFS= read -r dev; do
  [[ -e "$dev" ]] || continue
  name="$(udevadm info --query=property --name="$dev" 2>/dev/null | sed -n 's/^NAME=//p' | head -n1)"
  props="$(udevadm info --query=property --name="$dev" 2>/dev/null || true)"
  if grep -q '^ID_INPUT_JOYSTICK=1$' <<<"$props"; then
    printf 'Controller: %s (%s)\n' "${name:-unknown}" "$dev"
    [[ -r "$dev" ]] || { echo "FAIL: controller event node is not readable"; exit 1; }
    found=1
  fi
done < <(find /dev/input -maxdepth 1 -type c -name 'event*' -print 2>/dev/null | sort)
((found)) || { echo "FAIL: no Linux-input game controller detected"; exit 1; }
echo "PASS: controller is visible through native Linux input. Use evtest for every axis/button and force-feedback validation."
EOF
chmod 0755 /usr/local/bin/opi-controller-check
cat > /usr/local/bin/opi-audio-check <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
command -v wpctl >/dev/null
command -v bluetoothctl >/dev/null
dpkg -s libspa-0.2-bluetooth >/dev/null 2>&1
wpctl status > /tmp/opi-wpctl-status.txt
grep -Eqi 'HDMI|DisplayPort' /tmp/opi-wpctl-status.txt || { cat /tmp/opi-wpctl-status.txt; echo "FAIL: no HDMI/DisplayPort PipeWire sink detected"; exit 1; }
bluetoothctl list | grep -q '^Controller ' || { echo "FAIL: no Bluetooth controller detected"; exit 1; }
echo "PASS: HDMI audio sink and Bluetooth audio stack are available"
EOF
chmod 0755 /usr/local/bin/opi-audio-check
cat > /usr/local/bin/opi-nvme-check <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
mapfile -t devices < <(lsblk -dnpo NAME,TYPE,TRAN | awk '$2=="disk" && ($3=="nvme" || $1 ~ /nvme/) {print $1}')
((${#devices[@]})) || { echo "FAIL: no NVMe device detected"; exit 1; }
echo "Read-only NVMe inventory (no mount, format or write is performed):"
lsblk -d -o NAME,PATH,TRAN,MODEL,SERIAL,SIZE,RO,TYPE "${devices[@]}"
for dev in "${devices[@]}"; do nvme smart-log "$dev"; done
echo "PASS: NVMe enumerates and answers the read-only SMART command"
EOF
chmod 0755 /usr/local/bin/opi-nvme-check
cat > /usr/local/bin/opi-media-hwtest <<'EOF'
#!/usr/bin/env bash
set +e
echo "== DRM / GPU =="; ls -l /dev/dri 2>/dev/null
echo; echo "== Vulkan =="; vulkaninfo --summary 2>/dev/null | head -100
echo; echo "== V4L2 =="
for dev in /dev/video*; do [[ -e "$dev" ]] || continue; echo "--- $dev"; v4l2-ctl -d "$dev" --all 2>/dev/null | head -80; v4l2-ctl -d "$dev" --list-formats-out 2>/dev/null | head -80; done
echo; echo "== V4L2-request FFmpeg =="
LD_LIBRARY_PATH=/opt/opi/media/lib:/opt/opi/media/lib64 /opt/opi/media/bin/ffmpeg -hide_banner -hwaccels 2>/dev/null
echo
/usr/local/bin/opi-stremio-hwcheck
EOF
chmod 0755 /usr/local/bin/opi-media-hwtest
cat > /usr/local/bin/opi-validate <<'EOF'
#!/usr/bin/env bash
set +e
P=0; W=0; F=0; I=0
pass(){ echo "PASS $*"; P=$((P+1)); }; warn(){ echo "WARN $*"; W=$((W+1)); }; fail(){ echo "FAIL $*"; F=$((F+1)); }; info(){ echo "INFO $*"; I=$((I+1)); }
grep -qi 'Orange Pi 5 Pro\|orangepi5pro' /proc/device-tree/model 2>/dev/null && pass "Orange Pi 5 Pro" || warn "Board model string"
[[ "$(uname -m)" == aarch64 ]] && pass "AArch64" || fail "Not aarch64"
KVER="$(uname -r | sed 's/-.*//')"; [[ "$(printf '7.0\n%s\n' "$KVER" | sort -V | head -n1)" == "7.0" ]] && pass "Linux >= 7.0 ($KVER)" || fail "Kernel older than 7.0: $KVER"
systemctl --failed --no-legend 2>/dev/null | grep -q . && fail "Failed systemd units present" || pass "No failed systemd units"
for unit in greetd.service NetworkManager.service bluetooth.service opi-swapfile.service opi-performance.service earlyoom.service; do systemctl is-enabled "$unit" >/dev/null 2>&1 && pass "$unit enabled" || fail "$unit not enabled"; done
systemctl --global is-enabled opi-rom-scan.timer >/dev/null 2>&1 && pass "USB ROM scan timer enabled" || fail "USB ROM scan timer not enabled"
grep -qw consoleblank=0 /proc/cmdline && pass "Console blanking disabled" || warn "consoleblank=0 not present"
grep -qw cma=512M /proc/cmdline && pass "CMA 512M boot reservation" || fail "cma=512M not present"
if grep -q '^CmaTotal:' /proc/meminfo && awk '/^CmaTotal:/ {exit !($2 >= 500000)}' /proc/meminfo; then pass "CMA >= ~512MB"; else fail "CMA reservation below expected ~512MB"; fi
swapon --show=NAME --noheadings | grep -q '/dev/zram' && pass "zram swap active" || fail "zram swap not active"
test -e /dev/uinput && [[ -w /dev/uinput ]] && pass "/dev/uinput writable" || fail "/dev/uinput unavailable"
lsmod | awk '{print $1}' | grep -qx uinput && pass "uinput module loaded" || fail "uinput module not loaded"
lsmod | awk '{print $1}' | grep -qx uhid && pass "uhid module loaded" || fail "uhid module not loaded"
id -nG ryan | grep -qw input && pass "ryan in input group" || fail "ryan missing input group"
for cmd in es-de gamescope labwc opencode moonlight-qt; do command -v "$cmd" >/dev/null && pass "$cmd" || fail "$cmd missing"; done
command -v gamepad-osk >/dev/null && pass "gamepad-osk" || warn "gamepad-osk missing"
test -x /usr/local/bin/stremio && pass "Native Stremio launcher" || fail "Stremio launcher missing"
test -x /opt/stremio/stremio && pass "Native Stremio shell" || fail "Native Stremio shell missing"
command -v node >/dev/null && pass "Ubuntu ARM64 Node.js" || fail "Node.js missing"
test -f /opt/stremio/libopi-stremio-hwdec.so && pass "Stremio hwdec override" || fail "Stremio hwdec override missing"
if /usr/local/bin/opi-stremio-hwcheck >/tmp/opi-hwcheck.log 2>&1; then pass "REAL RK3588 hardware video decode"; else fail "Stremio hardware-decode gate failed; see /tmp/opi-hwcheck.log"; fi
if /usr/local/bin/opi-stremio-session-check >/tmp/opi-stremio-session-check.log 2>&1; then pass "Stremio process hardware-decode evidence"; else warn "Play H.264 and HEVC in Stremio, then run opi-stremio-session-check"; fi
if /usr/local/bin/opi-moonlight-hwcheck >/tmp/opi-moonlight-hwcheck.log 2>&1; then pass "Moonlight forced-hardware V4L2 Request stack"; else fail "Moonlight hardware policy failed; see /tmp/opi-moonlight-hwcheck.log"; fi
if /usr/local/bin/opi-moonlight-session-check >/tmp/opi-moonlight-session-check.log 2>&1; then pass "Moonlight native-display hardware-decoded stream evidence"; else warn "Complete a Moonlight stream at the detected display mode, then run opi-moonlight-session-check"; fi
for spec in "PS1:duckstation" "PS2:armsx2" "PSP:ppsspp" "N64:rmg" "Dreamcast:flycast" "GameCube/Wii:dolphin-emu" "GB/GBC:sameboy" "GBA:mgba-qt" "DS:melonds" "3DS:azahar" "NES:nestopia" "SNES:snes9x-gtk"; do name="${spec%%:*}"; exe="${spec#*:}"; command -v "$exe" >/dev/null && pass "$name emulator" || fail "$name emulator missing: $exe"; done
command -v brave-browser >/dev/null && pass "Brave default browser" || fail "Brave browser missing"
command -v firefox >/dev/null && pass "Firefox alternative browser" || fail "Firefox browser missing"
command -v wpctl >/dev/null && pass "PipeWire/WirePlumber" || fail "Audio tools missing"
dpkg -s libspa-0.2-bluetooth >/dev/null 2>&1 && pass "PipeWire Bluetooth audio" || fail "Bluetooth audio plugin missing"
if /usr/local/bin/opi-audio-check >/tmp/opi-audio-check.log 2>&1; then pass "HDMI + Bluetooth audio capability"; else fail "Audio capability gate failed; see /tmp/opi-audio-check.log"; fi
command -v nmcli >/dev/null && pass "NetworkManager" || fail "NetworkManager missing"
nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep -q ':wifi$' && pass "Wi-Fi interface detected" || fail "No Wi-Fi interface detected"
bluetoothctl list 2>/dev/null | grep -q '^Controller ' && pass "Bluetooth HCI controller detected" || fail "No Bluetooth HCI controller detected"
command -v cec-ctl >/dev/null && pass "Kernel HDMI-CEC tools" || warn "cec-ctl missing"
compgen -G '/dev/cec*' >/dev/null && pass "HDMI-CEC adapter node" || warn "No /dev/cec* node"
test -e /dev/dri/renderD128 && pass "DRM render node" || warn "DRM render node missing"
info "Stremio HW decode is a hard runtime gate: opi-stremio-hwcheck and post-playback opi-stremio-session-check must PASS"
info "Moonlight HW decode is a hard runtime gate: opi-moonlight-hwcheck and a detected-display opi-moonlight-session-check must PASS"
echo; echo "TOTAL: $P PASS, $W WARN, $F FAIL, $I INFO"; ((F==0))
EOF
chmod 0755 /usr/local/bin/opi-validate
cat > /usr/local/bin/opi-validation-report <<'EOF'
#!/usr/bin/env bash
set -o pipefail
out="${1:-$HOME/opi-validation-$(date +%Y%m%d-%H%M%S).log}"
/usr/local/bin/opi-validate 2>&1 | tee "$out"
status="${PIPESTATUS[0]}"
printf '\nValidation report: %s\n' "$out"
exit "$status"
EOF
chmod 0755 /usr/local/bin/opi-validation-report
