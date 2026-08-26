say "Verified persistent Armbian source mirror"
if [[ -L "$ARMBIAN_MIRROR" || ( -e "$ARMBIAN_MIRROR" && ! -d "$ARMBIAN_MIRROR/objects" ) ]]; then
    warn "Discarding invalid Armbian source mirror: $ARMBIAN_MIRROR"
    remove_workdir "$ARMBIAN_MIRROR" || die "Could not remove invalid Armbian source mirror"
fi
if [[ -d "$ARMBIAN_MIRROR/objects" && "$(git -C "$ARMBIAN_MIRROR" rev-parse --is-bare-repository 2>/dev/null || true)" != true ]]; then
    warn "Discarding non-bare Armbian source cache: $ARMBIAN_MIRROR"
    remove_workdir "$ARMBIAN_MIRROR" || die "Could not remove non-bare Armbian source cache"
fi
if [[ ! -d "$ARMBIAN_MIRROR/objects" ]]; then
    mirror_tmp="${ARMBIAN_MIRROR}.new.$$"
    remove_workdir "$mirror_tmp" || die "Could not clear temporary Armbian mirror path"
    git_net clone --mirror "$ARMBIAN_REPOSITORY" "$mirror_tmp"
    mv -- "$mirror_tmp" "$ARMBIAN_MIRROR"
    good "Created persistent Armbian source mirror"
fi
[[ "$(git -C "$ARMBIAN_MIRROR" config --get remote.origin.url)" == "$ARMBIAN_REPOSITORY" ]] || die "Armbian mirror origin is not the official repository"
GIT_NETWORK_TIMEOUT=15m git_net -C "$ARMBIAN_MIRROR" remote update --prune
git -C "$ARMBIAN_MIRROR" fsck --connectivity-only --no-dangling >/dev/null || die "Armbian source mirror failed connectivity verification"
[[ "$ARMBIAN_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Pinned Armbian commit is malformed"
git -C "$ARMBIAN_MIRROR" cat-file -e "${ARMBIAN_COMMIT}^{commit}" 2>/dev/null || die "Pinned Armbian commit is absent from the verified mirror: $ARMBIAN_COMMIT"
say "Fresh Armbian workspace from verified mirror"
[[ ! -e "$ARMBIAN" ]] || die "Armbian destination unexpectedly exists before clone"
GIT_NETWORK_TIMEOUT=15m git_net clone --no-local --no-hardlinks "$ARMBIAN_MIRROR" "$ARMBIAN"
git -C "$ARMBIAN" remote set-url origin "$ARMBIAN_REPOSITORY"
git -C "$ARMBIAN" checkout --detach "$ARMBIAN_COMMIT"
[[ "$(git -C "$ARMBIAN" rev-parse HEAD)" == "$ARMBIAN_COMMIT" ]] || die "Fresh Armbian checkout does not match the mirror commit"
[[ -z "$(git -C "$ARMBIAN" status --porcelain)" ]] || die "Fresh Armbian checkout is unexpectedly dirty"
USERPATCHES_DIR="$ARMBIAN/userpatches"
install -d -m0755 "$USERPATCHES_DIR"
[[ -d "$USERPATCHES_DIR" && -w "$USERPATCHES_DIR" ]] || die "Armbian userpatches directory is unavailable or not writable: $USERPATCHES_DIR"
good "Fresh Armbian userpatches directory initialized"
say "Armbian edge/mainline media preflight"
BOARD_CFG="$ARMBIAN/config/boards/orangepi5pro.csc"; FAMILY_COMMON="$ARMBIAN/config/sources/families/include/rockchip64_common.inc"; KCFG="$ARMBIAN/config/kernel/linux-rockchip64-edge.config"
[[ -s "$BOARD_CFG" ]] || die "Armbian Orange Pi 5 Pro board config is missing"; [[ -s "$FAMILY_COMMON" ]] || die "Armbian rockchip64 family include is missing"; [[ -s "$KCFG" ]] || die "Armbian rockchip64 edge kernel config is missing"
BOARD_KERNEL_TARGETS="$(sed -nE 's/^KERNEL_TARGET="([^"]+)".*/\1/p' "$BOARD_CFG" | head -n1)"; [[ -n "$BOARD_KERNEL_TARGETS" ]] || die "Could not parse KERNEL_TARGET from Orange Pi 5 Pro board config"; case ",${BOARD_KERNEL_TARGETS}," in *,edge,*) ;; *) die "Armbian no longer advertises edge for Orange Pi 5 Pro (KERNEL_TARGET=${BOARD_KERNEL_TARGETS})" ;; esac
EDGE_KERNEL_FAMILY="$(awk '/^[[:space:]]*edge\)[[:space:]]*$/ {in_edge=1; next} in_edge && /^[[:space:]]*;;[[:space:]]*$/ {exit} in_edge && /KERNEL_MAJOR_MINOR[[:space:]]*=/ {line=$0; sub(/.*KERNEL_MAJOR_MINOR[[:space:]]*=[[:space:]]*"/,"",line); sub(/".*/,"",line); if(line ~ /^[0-9]+\.[0-9]+$/){print line; exit}}' "$FAMILY_COMMON")"
EDGE_KERNEL_CONFIG="$(sed -nE 's/^# Armbian defconfig generated with ([0-9]+\.[0-9]+).*$/\1/p' "$KCFG" | head -n1)"
if [[ -n "$EDGE_KERNEL_FAMILY" && -n "$EDGE_KERNEL_CONFIG" && "$EDGE_KERNEL_FAMILY" != "$EDGE_KERNEL_CONFIG" ]]; then die "Armbian edge metadata disagrees: family=${EDGE_KERNEL_FAMILY}, config=${EDGE_KERNEL_CONFIG}"; fi
EDGE_KERNEL="${EDGE_KERNEL_FAMILY:-$EDGE_KERNEL_CONFIG}"; [[ "$EDGE_KERNEL" =~ ^[0-9]+\.[0-9]+$ ]] || die "Could not resolve Armbian edge kernel version from family/config metadata"; [[ "$(printf '7.0\n%s\n' "$EDGE_KERNEL" | sort -V | head -n1)" == 7.0 ]] || die "Armbian edge kernel $EDGE_KERNEL is older than Linux 7.0; RK3588 VDPU381 decode requires 7.0+"
grep -Eq '^CONFIG_VIDEO_ROCKCHIP_VDEC=(m|y)$' "$KCFG" || die "Armbian edge kernel config lacks Rockchip VDEC"; grep -Eq '^CONFIG_DRM_PANTHOR=(m|y)$' "$KCFG" || die "Armbian edge kernel config lacks Panthor"; grep -Eq '^CONFIG_DRM_ROCKCHIP=(m|y)$' "$KCFG" || die "Armbian edge kernel config lacks Rockchip DRM"; good "Armbian edge kernel ${EDGE_KERNEL}: Rockchip VDEC + Panthor + DRM configured"
BOARD_KERNEL_TEST_TARGETS="$(sed -nE 's/^KERNEL_TEST_TARGET="([^"]+)".*/\1/p' "$BOARD_CFG" | head -n1)"; case ",${BOARD_KERNEL_TEST_TARGETS}," in *,edge,*) good "Orange Pi 5 Pro edge is listed as an Armbian test target";; *) warn "Armbian exposes edge for Orange Pi 5 Pro but does not list it in KERNEL_TEST_TARGET; hardware boot/display validation remains mandatory";; esac
say "Installing explicit Orange Pi gaming kernel config"
[[ -d "$USERPATCHES_DIR" && -w "$USERPATCHES_DIR" ]] || die "Armbian userpatches directory disappeared before kernel config staging"
USER_KCFG="$USERPATCHES_DIR/linux-rockchip64-edge.config"; cp -- "$KCFG" "$USER_KCFG"; [[ -s "$USER_KCFG" ]] || die "Failed to stage edge kernel config in Armbian userpatches"
set_kcfg(){ local sym="$1" val="$2" cfg="$3"; sed -Ei "/^CONFIG_${sym}=.*/d; /^# CONFIG_${sym} is not set$/d" "$cfg"; printf 'CONFIG_%s=%s\n' "$sym" "$val" >> "$cfg"; }
while IFS='=' read -r key val; do [[ "$key" == CONFIG_* ]] || continue; set_kcfg "${key#CONFIG_}" "$val" "$USER_KCFG"; done < "$PROFILE_DIR/kernel/edge-overrides.conf"
for spec in "DRM_ROCKCHIP:y" "ROCKCHIP_DW_HDMI_QP:y" "DRM_DW_HDMI_QP_CEC:y" "MEDIA_CEC_SUPPORT:y" "RC_CORE:y" "MEDIA_CEC_RC:y" "SOUND:m" "SND:m" "SND_SOC:m" "SND_SOC_HDMI_CODEC:m" "SND_SOC_ROCKCHIP_I2S_TDM:m" "SND_SIMPLE_CARD:m" "DRM_PANTHOR:m" "VIDEO_ROCKCHIP_VDEC:m" "VIDEO_DEV:m" "MEDIA_SUPPORT:y" "MEDIA_CONTROLLER:y" "V4L_MEM2MEM_DRIVERS:y" "ZRAM:m" "ZRAM_BACKEND_ZSTD:y" "INPUT_UINPUT:m" "UHID:m" "JOYSTICK_XPAD:m" "HID_PLAYSTATION:m" "HID_NINTENDO:m" "HID_STEAM:m" "BRCMFMAC:m" "BRCMFMAC_SDIO:y" "BT:m" "BT_HCIUART:m" "BT_HCIUART_BCM:y" "RFKILL:m" "RFKILL_INPUT:y" "BTRFS_FS:y" "EXFAT_FS:m" "NTFS3_FS:m" "VFAT_FS:y" "F2FS_FS:m" "XFS_FS:m" "ISO9660_FS:m" "UDF_FS:m"; do sym="${spec%%:*}"; val="${spec#*:}"; grep -qx "CONFIG_${sym}=${val}" "$USER_KCFG" || die "Failed to stage CONFIG_${sym}=${val}"; done
good "Explicit controller/uinput/HDMI-CEC/HDMI-audio/filesystem kernel config staged"
jq --arg c "$ARMBIAN_COMMIT" '.armbian_commit=$c' "$LOCK" > "${LOCK}.tmp"; mv "${LOCK}.tmp" "$LOCK"
install -Dm0755 "$PROFILE_DIR/recipes/arm64-common.sh" "$SCRIPTS/arm64-common.sh"
