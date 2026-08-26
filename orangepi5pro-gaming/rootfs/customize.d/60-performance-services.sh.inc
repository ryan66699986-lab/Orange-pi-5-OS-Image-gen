log "4GB memory safety and maximum-performance appliance policy"
install -d -m0755 /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf.d/opi.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
cat > /usr/local/sbin/opi-ensure-swapfile <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
swap=/swapfile
root_fstype="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
if [[ "$root_fstype" == btrfs && -f "$swap" ]] && ! btrfs inspect-internal map-swapfile -r "$swap" >/dev/null 2>&1; then
  swapoff "$swap" 2>/dev/null || true
  rm -f -- "$swap"
fi
if [[ ! -f "$swap" ]]; then
  avail_kb="$(df -Pk / | awk 'NR==2 {print $4}')"; target_mb=2048
  if (( avail_kb < 3072 * 1024 )); then target_mb=1024; fi
  if (( avail_kb < 2048 * 1024 )); then target_mb=512; fi
  if (( avail_kb < 1280 * 1024 )); then echo "WARN: not enough free rootfs space for disk swap fallback; zram remains active" >&2; exit 0; fi
  if [[ "$root_fstype" == btrfs ]]; then
    touch "$swap"
    chattr +C "$swap"
    btrfs property set "$swap" compression none
  fi
  fallocate -l "${target_mb}M" "$swap" || dd if=/dev/zero of="$swap" bs=1M count="$target_mb" status=progress
  chmod 0600 "$swap"; mkswap "$swap"
fi
swapon --show=NAME --noheadings | grep -qx "$swap" || swapon -p 10 "$swap"
EOF
chmod 0755 /usr/local/sbin/opi-ensure-swapfile
cat > /etc/systemd/system/opi-swapfile.service <<'EOF'
[Unit]
Description=Create low-priority emergency swap file
After=local-fs.target armbian-resize-filesystem.service
Before=earlyoom.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/opi-ensure-swapfile
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/default/earlyoom <<'EOF'
EARLYOOM_ARGS="-r 60 -m 5 -s 10 --avoid '^(gamescope|es-de|greetd)$'"
EOF
cat > /usr/local/sbin/opi-performance <<'EOF'
#!/usr/bin/env bash
set -u
for g in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do [[ -w "$g" ]] && echo performance > "$g" || true; done
for g in /sys/class/devfreq/*/governor; do [[ -w "$g" ]] || continue; grep -qw performance "$(dirname "$g")/available_governors" 2>/dev/null && echo performance > "$g" || true; done
EOF
chmod 0755 /usr/local/sbin/opi-performance
cat > /etc/systemd/system/opi-performance.service <<'EOF'
[Unit]
Description=OPi maximum performance governor
After=armbian-hardware-optimize.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/opi-performance
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
install -d -m0755 /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/90-opi-appliance.conf <<'EOF'
[Login]
IdleAction=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandlePowerKey=poweroff
EOF
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
if [[ -f /boot/armbianEnv.txt ]]; then
  if grep -q '^extraargs=' /boot/armbianEnv.txt; then
    sed -Ei 's/[[:space:]]*consoleblank=[0-9]+//g' /boot/armbianEnv.txt; sed -Ei 's/[[:space:]]*cma=[^[:space:]]+//g' /boot/armbianEnv.txt; sed -Ei 's/^extraargs=(.*)$/extraargs=\1 consoleblank=0 zswap.enabled=0 cma=512M/' /boot/armbianEnv.txt
  else echo 'extraargs=consoleblank=0 zswap.enabled=0 cma=512M' >> /boot/armbianEnv.txt; fi
fi
log "Locale/timezone/services"
if grep -q '^# *en_GB.UTF-8 UTF-8' /etc/locale.gen 2>/dev/null; then sed -i 's/^# *en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen; fi
locale-gen en_GB.UTF-8
update-locale LANG=en_GB.UTF-8
ln -snf /usr/share/zoneinfo/Europe/London /etc/localtime; echo Europe/London > /etc/timezone
cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="gb"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
cat > /etc/default/crda <<'EOF'
REGDOMAIN=GB
EOF
cat > /usr/local/sbin/opi-set-regdomain <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
for attempt in {1..10}; do
  iw reg set GB
  iw reg get | grep -Eq '^country GB:' && exit 0
  sleep 1
done
echo "Unable to set Wi-Fi regulatory domain to GB" >&2
exit 1
EOF
chmod 0755 /usr/local/sbin/opi-set-regdomain
cat > /etc/systemd/system/opi-regdomain.service <<'EOF'
[Unit]
Description=Set United Kingdom Wi-Fi regulatory domain
After=NetworkManager.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/opi-set-regdomain
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
cat > /etc/apt/apt.conf.d/52opi-unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
EOF
systemctl disable lightdm.service 2>/dev/null || true
for unit in armbian-zram-config.service armbian-ramlog.service; do if systemctl cat "$unit" >/dev/null 2>&1; then systemctl disable "$unit" 2>/dev/null || true; systemctl mask "$unit"; fi; done
for unit in systemd-oomd.service systemd-oomd.socket; do if systemctl cat "$unit" >/dev/null 2>&1; then systemctl disable "$unit" 2>/dev/null || true; systemctl mask "$unit"; fi; done
systemctl enable greetd.service NetworkManager.service bluetooth.service opi-swapfile.service opi-performance.service opi-regdomain.service earlyoom.service
systemctl enable apt-daily.timer apt-daily-upgrade.timer
systemctl disable ssh.service 2>/dev/null || true; systemctl disable ssh.socket 2>/dev/null || true
systemctl --global enable opi-rom-scan.timer
cat > /home/ryan/ROMs/ports/Desktop-Mode.sh <<'EOF'
#!/usr/bin/env bash
exec desktop-mode
EOF
cat > /home/ryan/ROMs/ports/Direct-Gaming-Mode.sh <<'EOF'
#!/usr/bin/env bash
exec direct-gaming-mode
EOF
cat > /home/ryan/ROMs/ports/Reboot.sh <<'EOF'
#!/usr/bin/env bash
sudo systemctl reboot
EOF
cat > /home/ryan/ROMs/ports/Power-Off.sh <<'EOF'
#!/usr/bin/env bash
sudo systemctl poweroff
EOF
cat > /home/ryan/ROMs/ports/Restart-Gaming-Mode.sh <<'EOF'
#!/usr/bin/env bash
sudo opi-set-session gaming
sudo systemctl restart greetd
EOF
cat > /home/ryan/ROMs/ports/Steam-Experimental.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p "$HOME/.local/share/Steam"
steamsh="$(find "$HOME/.local/share/Steam" -type f -name steam.sh -print -quit 2>/dev/null || true)"
if [[ -z "$steamsh" ]]; then
  steam-arm64-bootstrap
  steamsh="$(find "$HOME/.local/share/Steam" -type f -name steam.sh -print -quit 2>/dev/null || true)"
fi
[[ -n "$steamsh" ]] || { echo "Steam ARM64 bootstrap did not install steam.sh"; exit 1; }
exec "$steamsh" -gamepadui
EOF
chmod 0755 /home/ryan/ROMs/ports/*.sh; chown -R ryan:ryan /home/ryan/ROMs/ports
chown -R ryan:ryan /home/ryan; rm -f /root/.not_logged_in_yet
