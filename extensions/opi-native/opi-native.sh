#!/usr/bin/env bash

function extension_prepare_config__opi_native_requirements() {
	[[ "${BOARD}" == "orangepi5pro" ]] || exit_with_error "opi-native only supports orangepi5pro"
	[[ "${ARCH}" == "arm64" ]] || exit_with_error "opi-native requires an arm64 image"
	[[ "${RELEASE}" == "resolute" ]] || exit_with_error "opi-native requires Ubuntu Resolute"
	[[ "${BRANCH}" == "edge" ]] || exit_with_error "opi-native requires the Armbian edge branch"
}

# These are hardware-enablement requirements, not user policy. Armbian invokes
# this hook once for artifact hashing and again with the kernel .config loaded.
function custom_kernel_config__opi_native_hardware_support() {
	opts_m+=(
		MEDIA_SUPPORT VIDEO_ROCKCHIP_VDEC VIDEO_HANTRO
		DRM_PANTHOR DRM_DW_HDMI_AHB_AUDIO DRM_DW_HDMI_GP_AUDIO
		INPUT_JOYDEV INPUT_UINPUT UHID BT_HIDP JOYSTICK_XPAD
		HID_NINTENDO HID_PLAYSTATION HID_SONY HID_STEAM
	)
	opts_y+=(VSI_IOMMU HIDRAW SND_SOC_ROCKCHIP_I2S_TDM)
}

function pre_customize_image__100_build_opi_native_applications() {
	local build_dir="${SDCARD}/tmp/opi-native-build"
	rm -rf -- "${build_dir}"
	mkdir -p "${build_dir}"
	cp -a "${EXTENSION_DIR}/." "${build_dir}/"
	chroot_sdcard env OPI_NATIVE_JOBS="${OPI_NATIVE_JOBS:-4}" /bin/bash /tmp/opi-native-build/build-in-image.sh
	rm -rf -- "${build_dir}"
}
