#!/usr/bin/env bash

function extension_prepare_config__opi_native_requirements() {
	[[ "${BOARD}" == "orangepi5pro" ]] || exit_with_error "opi-native only supports orangepi5pro"
	[[ "${ARCH}" == "arm64" ]] || exit_with_error "opi-native requires an arm64 image"
	[[ "${RELEASE}" == "resolute" ]] || exit_with_error "opi-native requires Ubuntu Resolute"
	[[ "${BRANCH}" == "edge" ]] || exit_with_error "opi-native requires the Armbian edge branch"
}

function late_family_config__opi_native_decoder_kernel() {
	local kernel_config="${SRC}/config/kernel/linux-rockchip64-edge.config"
	local setting
	[[ -f "${kernel_config}" ]] || exit_with_error "Missing Armbian edge kernel configuration"
	for setting in \
		CONFIG_MEDIA_SUPPORT=m \
		CONFIG_VIDEO_ROCKCHIP_VDEC=m \
		CONFIG_VIDEO_HANTRO=m \
		CONFIG_VSI_IOMMU=y; do
		grep -qx "${setting}" "${kernel_config}" || exit_with_error "Armbian edge kernel lacks ${setting}"
	done
}

function pre_customize_image__100_build_opi_native_applications() {
	local build_dir="${SDCARD}/tmp/opi-native-build"
	rm -rf -- "${build_dir}"
	mkdir -p "${build_dir}"
	cp -a "${EXTENSION_DIR}/." "${build_dir}/"
	chroot_sdcard env OPI_NATIVE_JOBS="${OPI_NATIVE_JOBS:-4}" /bin/bash /tmp/opi-native-build/build-in-image.sh
	rm -rf -- "${build_dir}"
}
