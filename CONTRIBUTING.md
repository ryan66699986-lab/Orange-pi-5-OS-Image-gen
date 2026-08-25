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

## Change contract

Every change should state:

- the observed problem or requirement;
- the layer that owns it;
- why the selected correction is preferable to alternatives;
- which static, target-root, offline-image and physical gates are affected;
- what remains unproven after repository CI.

Do not broaden the image opportunistically while fixing an unrelated failure. New packages and services consume storage, memory, attack surface and validation time.

## Required documentation updates

- Product behavior or acceptance criteria: `docs/REQUIREMENTS.md` and `docs/VALIDATION.md`.
- Architecture or a reversed choice: `docs/ARCHITECTURE.md` and `docs/DESIGN-DECISIONS.md`.
- Component/pin/acquisition change: `docs/COMPONENTS.md`, `THIRD_PARTY.md` and references where applicable.
- Emulator mapping/format change: `docs/EMULATION.md` and generated ES-DE configuration.
- Runtime helper or operator behavior: `docs/OPERATIONS.md` and `docs/TROUBLESHOOTING.md`.
- Storage behavior: `docs/STORAGE.md`, security review and NVMe mutation guards.
- Image-affecting change: increment `VERSION`, update `CHANGELOG.md`, `STATUS.md` and add/update the generation audit.

Documentation-only changes do not increment the image generation when they accurately describe the already merged image behavior.

## Validation before review

```bash
git diff --check
./tools/check.sh
```

Review every generated-payload result and the documentation-link pass. For shell changes, ensure errors are not hidden by pipelines, command substitution or `|| true`. For package changes, update early package resolution and final target/offline assertions together.

## Source updates

- Pin a release/tag in `sources.env`; resolve it to an immutable commit during the build.
- Inspect upstream release notes and build layout.
- Keep Git/download calls bounded and non-interactive.
- Verify final checkout commit and hash downloaded assets.
- Never relax a fingerprint, linkage or architecture assertion simply to accommodate an unexplained upstream change.

## Failure-driven changes

Attach or retain the complete log, identify the first causal failure, and classify later cleanup noise. A validator may be wrong, but changing it requires proof from the actual target data or authoritative upstream format plus a regression fixture. Start the corrected build from a fresh workspace.

## Review and merge

Use a branch and pull request, require CI, and verify remote content matches the locally validated files. Keep commits coherent. The final merge description should distinguish what is statically proven from what needs a new full build or hardware test.
