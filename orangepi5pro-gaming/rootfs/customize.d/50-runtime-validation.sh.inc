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
echo "PASS: RK3588 H.264 + HEVC + HEVC Main10 hardware-decode gate"
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
for spec in "PS1:duckstation" "PS2:armsx2" "PSP:ppsspp" "N64:rmg" "Dreamcast:flycast" "GameCube/Wii:dolphin-emu" "GB/GBC:sameboy" "GBA:mgba-qt" "DS:melonds" "3DS:azahar" "NES:nestopia" "SNES:snes9x-gtk"; do name="${spec%%:*}"; exe="${spec#*:}"; command -v "$exe" >/dev/null && pass "$name emulator" || fail "$name emulator missing: $exe"; done
command -v epiphany >/dev/null && pass "Epiphany/Web browser" || fail "Epiphany browser missing"
command -v wpctl >/dev/null && pass "PipeWire/WirePlumber" || fail "Audio tools missing"
dpkg -s libspa-0.2-bluetooth >/dev/null 2>&1 && pass "PipeWire Bluetooth audio" || fail "Bluetooth audio plugin missing"
command -v nmcli >/dev/null && pass "NetworkManager" || fail "NetworkManager missing"
nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep -q ':wifi$' && pass "Wi-Fi interface detected" || fail "No Wi-Fi interface detected"
bluetoothctl list 2>/dev/null | grep -q '^Controller ' && pass "Bluetooth HCI controller detected" || fail "No Bluetooth HCI controller detected"
command -v cec-ctl >/dev/null && pass "Kernel HDMI-CEC tools" || warn "cec-ctl missing"
compgen -G '/dev/cec*' >/dev/null && pass "HDMI-CEC adapter node" || warn "No /dev/cec* node"
test -e /dev/dri/renderD128 && pass "DRM render node" || warn "DRM render node missing"
info "Stremio HW decode is a hard runtime gate: opi-stremio-hwcheck and post-playback opi-stremio-session-check must PASS"
echo; echo "TOTAL: $P PASS, $W WARN, $F FAIL, $I INFO"; ((F==0))
EOF
chmod 0755 /usr/local/bin/opi-validate
