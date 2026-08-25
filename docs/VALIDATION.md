# Validation

Validation is split into four layers:

1. repository/static checks;
2. successful Armbian image generation;
3. offline inspection of the completed raw image;
4. actual Orange Pi 5 Pro hardware validation.

Only layer 4 can prove HDMI/display behavior, GPU acceleration, onboard wireless, controllers, thermal stability and RK3588 hardware video decoding.

Stremio is a hard gate. Run `opi-stremio-hwcheck`; the bundled H.264, HEVC 8-bit, HEVC Main10/HDR10, VP9 and AV1 probes—including the 4K set—must all decode through `v4l2request-copy`. Run `opi-stremio-hwcheck --visible` from the graphical session to prove the frames are displayed, then play representative content inside Stremio and run `opi-stremio-session-check`. Both helpers must pass. A working UI with software-decoded or blank video is a failure.

Moonlight hardware decode is also a hard gate. Launching Moonlight runs `opi-moonlight-display-auto`, which records the active output's current/preferred resolution and refresh rate and enables HDR only when the active connector's EDID advertises HDR static metadata. Run `opi-moonlight-hwcheck`, complete a stream at the detected mode, then run `opi-moonlight-session-check`. The latter requires both the exact detected resolution and an affirmative `hardware-accelerated` decoder record from the pinned Moonlight binary. On a 4K screen this remains a real 4K gate.

Run `opi-controller-check` with each available controller, then use `evtest` to exercise every button, stick, trigger and D-pad. The EasySMX X20 must be tested over USB, the 2.4 GHz receiver and Bluetooth. Verify Guide+Start toggles the OSK and that the controller mouse can operate Brave, Firefox, network and audio dialogs. Run `opi-audio-check` while HDMI/DisplayPort is attached; it requires an HDMI/DisplayPort PipeWire sink, a Bluetooth controller and the PipeWire Bluetooth plugin. Confirm HDMI is the initial default, then select a Bluetooth sink and verify routing follows the user's selection.

Run the aggregate validation and retain its report:

```bash
opi-validation-report
```

Also prove both browsers, Wi-Fi setup, Bluetooth keyboard/mouse pairing, ES-DE scraping, every emulator family with representative content, RetroAchievements sign-in where supported, the Labwc fallback, Steam's visible experimental launcher, 4 GB memory pressure, the Geekworm 515 fan and sustained maximum-performance thermal behavior.

The installed NVMe can be checked without changing it:

```bash
sudo opi-nvme-check
```

This performs only inventory and SMART reads. Do not mount, partition, format, or migrate the OS to NVMe until the image passes all release gates. At that point, `armbian-install` is the intended interactive migration tool for SD boot plus a Btrfs NVMe root. Later, eMMC becomes the preferred boot device while the root filesystem stays on NVMe; remove the SD card only after that arrangement cold-boots successfully.
