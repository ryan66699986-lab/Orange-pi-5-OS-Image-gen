# Validation

Validation is split into four layers:

1. repository/static checks;
2. successful Armbian image generation;
3. offline inspection of the completed raw image;
4. actual Orange Pi 5 Pro hardware validation.

Only layer 4 can prove HDMI/display behavior, GPU acceleration, onboard wireless, controllers, thermal stability and RK3588 hardware video decoding.

Stremio is a hard gate. Run `opi-stremio-hwcheck`; the bundled H.264, HEVC 8-bit and HEVC Main10 probes must all decode through `v4l2request-copy`. Run `opi-stremio-hwcheck --visible` from the graphical session to prove the frames are displayed, then play H.264 and HEVC content inside Stremio and run `opi-stremio-session-check`. Both helpers must pass. A working UI with software-decoded or blank video is a failure.
