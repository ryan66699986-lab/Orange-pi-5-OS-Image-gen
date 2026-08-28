#!/usr/bin/env bash

function extension_prepare_config__opi_native_packages() {
	[[ "${BOARD}" == "orangepi5pro" ]] || exit_with_error "opi-native only supports orangepi5pro"
	[[ "${ARCH}" == "arm64" ]] || exit_with_error "opi-native requires an arm64 image"
	[[ "${RELEASE}" == "resolute" ]] || exit_with_error "opi-native requires Ubuntu Resolute"
	[[ "${BRANCH}" == "current" ]] || exit_with_error "opi-native requires the Armbian current branch"

	# Use Armbian's supported package-list API. Kernel configuration is left
	# entirely to the pinned Armbian current profile.
	add_packages_to_rootfs \
		greetd tuigreet gamescope labwc foot xwayland seatd dbus-user-session \
		pipewire-audio wireplumber libspa-0.2-bluetooth alsa-utils pavucontrol playerctl \
		bluez blueman network-manager network-manager-applet nm-connection-editor \
		swaybg waybar mako-notifier udiskie udisks2 policykit-1-gnome libfuse2t64 \
		desktop-file-utils xdg-utils xdg-user-dirs locales mesa-utils mesa-vulkan-drivers \
		vulkan-tools v4l-utils libinput-tools joystick evtest python3-evdev edid-decode \
		gamemode nvme-cli usbutils pciutils git curl ca-certificates jq unzip \
		firefox snapd dolphin-emu dolphin-emu-data mgba-qt sameboy nestopia \
		libsdl3-0 libsdl3-ttf0 libsdl2-ttf-2.0-0 libqt6quickcontrols2-6 libglew2.2
}

function pre_customize_image__100_build_opi_native_applications() {
	local build_dir="${SDCARD}/tmp/opi-native-build"
	rm -rf -- "${build_dir}"
	mkdir -p "${build_dir}"
	cp -a "${EXTENSION_DIR}/." "${build_dir}/"
	chroot_sdcard env OPI_NATIVE_JOBS="${OPI_NATIVE_JOBS:-4}" /bin/bash /tmp/opi-native-build/build-in-image.sh
	rm -rf -- "${build_dir}"
}
