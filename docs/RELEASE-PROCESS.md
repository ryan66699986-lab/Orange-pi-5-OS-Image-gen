# Release process

Project versions are development generations until all build, offline and physical gates pass. A number in `VERSION` does not imply stability.

## 1. Define the change

- State the defect, requirement or upstream update.
- Identify affected build/runtime layers and dependent validation suites.
- Update `DESIGN-DECISIONS.md` if the change reverses a settled choice.
- Update `REQUIREMENTS.md` if product behavior or release criteria change.

Documentation-only improvements that do not change the image may remain in the current generation. Any recipe, package, pin, kernel, rootfs or validation behavior change increments `VERSION` before the next build.

## 2. Implement fail-closed

- Make the smallest coherent source change.
- Add an early/static regression where possible.
- Add target-root and offline-image assertions for runtime files/dependencies.
- Preserve source pins and bounded network operations.
- Keep dependency/download/compiler caches and the official bare Armbian mirror external, verified and unable to contain final artifacts or mutable rootfs state.
- Do not suppress mandatory install/build failures with `|| true`.
- Never add installed-NVMe mutation to the build profile.

## 3. Repository validation

```bash
git diff --check
./tools/check.sh
```

Review the complete diff, generated-payload checks, documentation links and forbidden-stack/NVMe guards. Commit atomically on a review branch.

## 4. Pull request and CI

- Push the review branch.
- Verify remote blobs match the locally validated commit.
- Open a pull request describing cause, change, gates and remaining physical proof.
- Require `Static checks` CI to pass.
- Merge with an auditable commit message; verify `main` content and `VERSION` afterwards.

## 5. Fresh candidate build

Use a new repository checkout if desired, but more importantly let `build.sh` create a completely fresh detached Armbian checkout and versioned output workspace from the verified mirror. Record the repository commit. Do not reuse any previous userpatch, rootfs, build directory or artifact.

If the build fails, audit the complete log, fix the repository, increment the generation for a changed image and start again. A partial image is never promoted.

## 6. Image handling

- Require terminal success and completed offline QA.
- Record image filename, byte size and SHA-256.
- Preserve source lock, artifact hashes and full log.
- Preserve the stage timing table and cache-hit statistics.
- Flash separate test media and verify the written media where the flashing tool permits it.
- Keep the prior known-good SD untouched.

## 7. Physical validation

Copy `VALIDATION-RECORD-TEMPLATE.md` into the candidate's external evidence folder and complete every applicable row. Run the ordered suite in `VALIDATION.md`. Hard failures return the generation to development; do not relabel them as known limitations.

## 8. Promotion

A candidate may be called known-good/final only when:

- all hard requirements pass;
- Stremio's own playback proves hardware decoding and visible video;
- Moonlight completes detected-mode hardware streaming;
- every emulator family is proven;
- controller-only, audio, network, display and thermal requirements pass;
- no unexplained WARN/FAIL remains;
- the evidence record is tied to the exact image hash and repository commit.

Cache-assisted builds remain candidates because cache hits do not bypass any gate. Before final promotion, review all cache validation messages and ensure any cache miss rebuilt successfully; never substitute a cached native artifact for a rebuilt one.

Classify validation outcomes using `/etc/opi/component-policy.tsv`: any `core` failure rejects even an MVP candidate; `required` items may be diagnosed after first boot but all must pass before final promotion; `experimental` Steam/GE-Proton failures remain recorded and non-blocking.

After promotion, ordinary same-release package maintenance may use `opi-update`. A distribution-suite change or project-managed source-bundle update is a release change: build/test it separately, prove the core and required gates, and retain a recovery SD before rollout.

Then update `STATUS.md` and `CHANGELOG.md`, commit the completed evidence summary (never private logs/content), run CI, merge and create an annotated Git tag matching the approved generation.

## 9. Storage promotion

Stable-image approval precedes NVMe migration. Follow `STORAGE.md`: SD-only → SD boot/NVMe Btrfs root → eMMC boot/NVMe Btrfs root. Revalidate after each topology change. The SD card remains rescue media even after normal boot no longer needs it.

## Rollback

- Source rollback: revert through a reviewed commit; do not rewrite release history.
- Image rollback: reflash the last known-good image/SD and verify its stored checksum.
- Storage rollback: preserve NVMe data and restore a known-good SD boot path before making further changes.
- Upstream security issue: document the exposure, pin/fix, rebuild from fresh sources and rerun all dependent gates before republishing.
