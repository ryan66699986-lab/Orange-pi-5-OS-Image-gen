# Third-party software

This project orchestrates or packages software from Armbian, Ubuntu and multiple emulator/media upstreams. It does not relicense those projects.

Notable upstream components include Armbian, Ubuntu, Linux, Mesa, Gamescope, greetd/tuigreet, Labwc, gamepad-osk, ES-DE, DuckStation, ARMSX2, PPSSPP, RMG, Flycast, Dolphin, SameBoy, mGBA, melonDS, Azahar, Nestopia, Snes9x, Stremio, FFmpeg, mpv, Moonlight, PipeWire/WirePlumber, Brave, Firefox, OpenCode, Steam and GE-Proton.

Exact tags/branches requested by the current profile are in `orangepi5pro-gaming/sources.env`. Resolved commits and downloaded-file hashes are generated per build rather than duplicated in this document. Upstream project links are catalogued in `docs/REFERENCES.md`, and integration/acquisition methods are described in `docs/COMPONENTS.md`.

Redistribution of a generated image must account for the licenses, source-offer/notice requirements and trademarks of every included binary and package. This repository's orchestration does not grant rights beyond those upstream terms. Before public distribution, generate and review a complete package/license inventory from the exact image and supply corresponding notices/source where required.

ROMs and copyrighted BIOS files are not part of this repository or generated image.

Steam/GE-Proton material is optional and experimental. Browser packages are obtained from their official repositories. Their presence does not imply endorsement by or affiliation with those projects.
