say "ARM64 distro executable/path preflight"
docker run --rm --platform linux/arm64 ubuntu:26.04 bash -ceu '
  export DEBIAN_FRONTEND=noninteractive
  sed -Ei "s/^Components:.*/Components: main restricted universe multiverse/" /etc/apt/sources.list.d/ubuntu.sources
  apt-get update >/dev/null
  apt-get install -y --no-install-recommends gamescope dolphin-emu sameboy mgba-qt nestopia v4l-utils kmod greetd tuigreet labwc waybar fuzzel mako-notifier udiskie xwayland swaybg network-manager-gnome blueman policykit-1-gnome pcmanfm-qt kitty epiphany-browser >/dev/null
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"
  for c in gamescope dolphin-emu sameboy mgba-qt nestopia cec-ctl lsmod greetd tuigreet labwc waybar fuzzel mako udiskie Xwayland swaybg nm-applet blueman-applet pcmanfm-qt kitty epiphany; do path="$(command -v "$c")"; [[ -x "$path" ]] || { echo "Expected distro/session executable is missing: $c" >&2; exit 1; }; printf "%s -> %s\n" "$c" "$path"; done
  test -x /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 || { echo "polkit-gnome authentication agent path changed" >&2; exit 1; }
  getent passwd _greetd >/dev/null || { echo "greetd package did not create _greetd user" >&2; exit 1; }
  test -f /usr/lib/systemd/system/greetd.service || { echo "greetd service path changed" >&2; exit 1; }
'
good "Distro emulator/system executable names resolve on ARM64"
