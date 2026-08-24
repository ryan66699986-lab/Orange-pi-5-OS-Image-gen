say "Final pre-Armbian static audit"
bash -n "$USERPATCHES_DIR/customize-image.sh" || die "customize-image.sh contains shell syntax errors"
[[ -s "$USERPATCHES_DIR/linux-rockchip64-edge.config" ]] || die "Explicit edge kernel config is missing"
grep -qx 'CONFIG_INPUT_UINPUT=m' "$USERPATCHES_DIR/linux-rockchip64-edge.config" || die "uinput kernel config was lost"
grep -qx 'CONFIG_ROCKCHIP_DW_HDMI_QP=y' "$USERPATCHES_DIR/linux-rockchip64-edge.config" || die "RK3588 HDMI-QP kernel config was lost"
grep -qx 'CONFIG_DRM_DW_HDMI_QP_CEC=y' "$USERPATCHES_DIR/linux-rockchip64-edge.config" || die "HDMI CEC kernel config was lost"
good "Builder/customizer/kernel-config static audit passed"
say "Starting Armbian Docker build"
cd "$ARMBIAN" || die "Unable to enter the fresh Armbian workspace"
./compile.sh build PREFER_DOCKER=yes BOARD=orangepi5pro BRANCH=edge RELEASE=resolute ROOTFS_TYPE=ext4 BUILD_MINIMAL=yes BUILD_DESKTOP=no NETWORKING_STACK=network-manager KERNEL_CONFIGURE=no EXPERT=yes COMPRESS_OUTPUTIMAGE=sha,img SHARE_LOG=no
say "Locating raw image"
mapfile -t IMAGES < <(find "$ARMBIAN/output/images" -maxdepth 1 -type f -name '*.img' -printf '%T@ %p\n' | sort -nr | awk '{print $2}')
((${#IMAGES[@]})) || die "No uncompressed .img found under Armbian output/images"
SOURCE_IMAGE="${IMAGES[0]}"
