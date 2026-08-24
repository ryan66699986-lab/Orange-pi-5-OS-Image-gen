# Contributing

This repository is the canonical development source for the Orange Pi 5 Pro image.

## Rules

- Never reuse an Armbian workspace after a failed image build.
- Fix the first real failure from the log; do not patch cleanup noise.
- Keep source pins explicit and reviewable.
- Do not add RetroArch/libretro, XFCE, LightDM or a vendor-kernel dependency to the gaming profile without an explicit architecture decision.
- Stremio hardware decode and controller-first operation are release gates.
- Run `./tools/check.sh` before committing.
- Do not commit ROMs, BIOS files, credentials, password hashes, generated images or build logs containing secrets.
