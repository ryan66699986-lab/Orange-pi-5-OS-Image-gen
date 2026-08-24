# Validation

Validation is split into four layers:

1. repository/static checks;
2. successful Armbian image generation;
3. offline inspection of the completed raw image;
4. actual Orange Pi 5 Pro hardware validation.

Only layer 4 can prove HDMI/display behavior, GPU acceleration, onboard wireless, controllers, thermal stability and RK3588 hardware video decoding.

Stremio is a hard gate. Run `opi-stremio-hwcheck`; the bundled H.264, HEVC 8-bit, HEVC Main10/HDR10, VP9 and AV1 probes—including the 4K set—must all decode through `v4l2request-copy`. Run `opi-stremio-hwcheck --visible` from the graphical session to prove the frames are displayed, then play representative content inside Stremio and run `opi-stremio-session-check`. Both helpers must pass. A working UI with software-decoded or blank video is a failure.

Moonlight hardware decode is also a hard gate. Run `opi-moonlight-hwcheck`, complete a 3840×2160 stream, then run `opi-moonlight-session-check`. The latter requires both a 4K stream record and an affirmative `hardware-accelerated` decoder record from the pinned Moonlight binary.

With the EasySMX X20 connected, run `opi-controller-check`, then use `evtest` to exercise every button, stick, trigger and D-pad over USB, the 2.4 GHz receiver and Bluetooth. Run `opi-audio-check` while HDMI/DisplayPort is attached; it requires an HDMI/DisplayPort PipeWire sink, a Bluetooth controller and the PipeWire Bluetooth plugin.

The installed NVMe can be checked without changing it:

```bash
sudo opi-nvme-check
```

This performs only inventory and SMART reads. Do not mount, partition, format, or migrate the OS to NVMe until the image passes all release gates. At that point, `armbian-install` is the intended interactive migration tool for SD boot plus NVMe root.
