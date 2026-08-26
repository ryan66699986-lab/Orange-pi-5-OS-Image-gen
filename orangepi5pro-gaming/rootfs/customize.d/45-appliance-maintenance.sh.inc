log "Appliance component policy and same-release updater"
install -d -m0755 /etc/opi /etc/update-manager /var/log/opi-update
cat > /etc/opi/component-policy.tsv <<'EOF'
tier	component	release meaning
core	boot-graphics-session	The appliance must boot, render and provide ES-DE or its Labwc recovery path
core	controller-input	Controller navigation, mouse emulation and OSK must work
core	stremio-hardware-decode	Native Stremio and its pinned V4L2 Request media stack must work
core	moonlight	Moonlight must launch with the pinned hardware-decoding policy
core	network-audio	NetworkManager, PipeWire and WirePlumber must remain healthy
required	gamescope	Preferred gaming compositor; a nonzero failure invokes direct Labwc gaming
required	emulator-catalogue	Every declared standalone emulator is required before final approval
required	firefox-cec-storage	Alternative browser, CEC input and removable-storage support are final requirements
experimental	steam-ge-proton	Visible for testing but never a stable release gate
EOF

cat > /usr/local/bin/opi-appliance-health <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
strict=0
[[ "${1:-}" == --strict ]] && strict=1
core_fail=0
required_fail=0
experimental_fail=0

result() {
    local tier="$1" status="$2" label="$3"
    printf '%-12s %-5s %s\n' "[$tier]" "$status" "$label"
    [[ "$status" == PASS ]] && return 0
    case "$tier" in core) ((core_fail+=1));; required) ((required_fail+=1));; experimental) ((experimental_fail+=1));; esac
}
check_cmd() { command -v "$3" >/dev/null 2>&1 && result "$1" PASS "$2" || result "$1" FAIL "$2 ($3 missing)"; }
check_file() { [[ -e "$3" ]] && result "$1" PASS "$2" || result "$1" FAIL "$2 ($3 missing)"; }

[[ "$(dpkg --print-architecture 2>/dev/null)" == arm64 ]] && result core PASS "ARM64 operating system" || result core FAIL "ARM64 operating system"
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    [[ "${ID:-}" == ubuntu && "${VERSION_CODENAME:-}" == resolute ]] && result core PASS "Ubuntu Resolute update boundary" || result core FAIL "Ubuntu Resolute update boundary"
else
    result core FAIL "Operating-system release metadata"
fi
if [[ -r /proc/device-tree/model ]]; then
    tr -d '\0' < /proc/device-tree/model | grep -Fqi 'Orange Pi 5 Pro' && result core PASS "Orange Pi 5 Pro hardware" || result core FAIL "Orange Pi 5 Pro hardware"
fi

for spec in \
  'core|ES-DE|es-de' 'core|Labwc recovery|labwc' 'core|Controller OSK|gamepad-osk' \
  'core|Brave browser|brave-browser' 'core|NetworkManager CLI|nmcli' 'core|PipeWire control|wpctl' \
  'core|Moonlight|moonlight-qt' 'required|Gamescope|gamescope' 'required|Firefox|firefox' \
  'required|DuckStation|duckstation' 'required|ARMSX2|armsx2' 'required|PPSSPP|ppsspp' \
  'required|RMG|rmg' 'required|Flycast|flycast' 'required|melonDS|melonds' \
  'required|Azahar|azahar' 'required|Snes9x|snes9x-gtk' 'required|Dolphin|dolphin-emu' \
  'required|SameBoy|sameboy' 'required|mGBA|mgba-qt' 'required|Nestopia|nestopia'; do
    IFS='|' read -r tier label cmd <<<"$spec"; check_cmd "$tier" "$label" "$cmd"
done
for spec in \
  'core|Native Stremio|/opt/stremio/stremio' \
  'core|Pinned Stremio media stack|/opt/opi/media/bin/mpv' \
  'core|Build source lock|/opt/opi-build-meta/versions.lock.json' \
  'required|CEC validation|/usr/local/bin/opi-cec-check' \
  'experimental|Steam test entry|/home/ryan/ROMs/ports/Steam-Experimental.sh'; do
    IFS='|' read -r tier label path <<<"$spec"; check_file "$tier" "$label" "$path"
done

for unit in greetd.service NetworkManager.service bluetooth.service; do
    systemctl is-enabled "$unit" >/dev/null 2>&1 && result core PASS "$unit enabled" || result core FAIL "$unit enabled"
done
if jq -e '.components | type == "object"' /opt/opi-build-meta/versions.lock.json >/dev/null 2>&1; then result core PASS "Build source lock JSON"; else result core FAIL "Build source lock JSON"; fi
if [[ -n "$(dpkg --audit 2>/dev/null)" ]]; then result core FAIL "dpkg database audit"; else result core PASS "dpkg database audit"; fi
for elf in /opt/stremio/stremio /opt/opi/media/bin/mpv /opt/opi/apps/moonlight/moonlight-qt; do
    linkage=""
    if [[ -x "$elf" ]] && linkage="$(ldd "$elf" 2>&1)" && ! grep -q 'not found' <<<"$linkage"; then result core PASS "Runtime linkage: $elf"; else result core FAIL "Runtime linkage: $elf"; fi
done

printf '\nHealth summary: core=%d required=%d experimental=%d\n' "$core_fail" "$required_fail" "$experimental_fail"
(( core_fail == 0 )) || exit 1
(( strict == 0 || required_fail == 0 )) || exit 2
exit 0
EOF
chmod 0755 /usr/local/bin/opi-appliance-health

cat > /usr/local/sbin/opi-update <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
mode="${1:-check}"
case "$mode" in check|apply|health) ;; *) echo "Usage: sudo opi-update check|apply|health" >&2; exit 2;; esac
(( EUID == 0 )) || { echo "opi-update must run through sudo" >&2; exit 1; }
install -d -m0755 /run/lock /var/log/opi-update
exec 9>/run/lock/opi-update.lock
flock -n 9 || { echo "Another appliance update is already running" >&2; exit 1; }
stamp="$(date +%Y%m%d-%H%M%S)"
log="/var/log/opi-update/${stamp}-${mode}.log"
exec > >(tee -a "$log") 2>&1

echo "Orange Pi appliance updater: $mode"
echo "Log: $log"
[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo "Refusing update outside ARM64" >&2; exit 1; }
[[ -r /proc/device-tree/model ]] && tr -d '\0' < /proc/device-tree/model | grep -Fqi 'Orange Pi 5 Pro' || { echo "Refusing update outside Orange Pi 5 Pro hardware" >&2; exit 1; }
. /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_CODENAME:-}" == resolute ]] || { echo "Refusing cross-release update: expected Ubuntu Resolute" >&2; exit 1; }

if [[ "$mode" == health ]]; then exec /usr/local/bin/opi-appliance-health --strict; fi

echo "Checking current appliance health before package maintenance"
/usr/local/bin/opi-appliance-health
echo
echo "Refreshing signed package metadata"
apt-get update
echo
echo "Available same-release package updates"
apt list --upgradable 2>/dev/null || true
echo
echo "Package holds (respected; change Armbian firmware policy separately and deliberately)"
apt-mark showhold || true
echo
echo "APT simulation (upgrade never removes installed packages)"
apt-get -s upgrade
echo
echo "Image-managed source builds remain pinned and are not silently replaced by APT:"
jq -r '.components | to_entries[] | "  \(.key)=\(.value)"' /opt/opi-build-meta/versions.lock.json 2>/dev/null || true
echo "A future signed project bundle is required to replace those pinned components without reflashing."

[[ "$mode" == apply ]] || exit 0
if pgrep -f '(^|/)(gamescope|es-de|stremio|moonlight-qt|brave-browser|firefox|steam)( |$)' >/dev/null 2>&1; then
    echo "Close Gaming Mode, browsers, Stremio, Moonlight and Steam before applying updates." >&2
    echo "Switch to Labwc Desktop Mode, close applications, then retry." >&2
    exit 1
fi
avail_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
(( avail_kb >= 1572864 )) || { echo "At least 1.5 GiB free space is required before updating" >&2; exit 1; }
printf '\nType UPDATE to apply same-release package upgrades: ' >/dev/tty
read -r answer </dev/tty
[[ "$answer" == UPDATE ]] || { echo "Update cancelled"; exit 0; }
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort > "/var/log/opi-update/${stamp}-packages-before.tsv"
apt-get upgrade
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort > "/var/log/opi-update/${stamp}-packages-after.tsv"
[[ -z "$(dpkg --audit)" ]] || { echo "Package database requires attention after update" >&2; dpkg --audit >&2; exit 1; }
echo
echo "Post-update core health"
/usr/local/bin/opi-appliance-health
if [[ -e /run/reboot-required ]]; then
    echo "A reboot is required. Review the log, then reboot from the system menu."
else
    echo "Same-release package update completed; no reboot marker was created."
fi
EOF
chmod 0755 /usr/local/sbin/opi-update

cat > /etc/update-manager/release-upgrades <<'EOF'
[DEFAULT]
Prompt=never
EOF
cat > /usr/share/applications/opi-system-update.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=OPi System Update
Comment=Review and apply same-release Armbian/Ubuntu/application package updates
Exec=kitty --hold --title "OPi System Update" sudo /usr/local/sbin/opi-update apply
Icon=system-software-update
Categories=System;Settings;
Terminal=false
EOF
desktop-file-validate /usr/share/applications/opi-system-update.desktop

cat > /home/ryan/ROMs/ports/Check-System-Updates.sh <<'EOF'
#!/usr/bin/env bash
exec kitty --hold --title "OPi Update Check" sudo /usr/local/sbin/opi-update check
EOF
chmod 0755 /home/ryan/ROMs/ports/Check-System-Updates.sh
chown ryan:ryan /home/ryan/ROMs/ports/Check-System-Updates.sh
