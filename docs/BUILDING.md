# Building

## Host

Use an x86_64 Linux host with Docker, binfmt/QEMU support and substantial free disk space.

Run:

```bash
./tools/check.sh
./build.sh
```

The builder prompts for the initial `ryan` password, hashes it immediately, and does not intentionally log the plaintext value.

## Fresh workspace invariant

Every attempt uses a fresh versioned workspace under the builder user's home directory. A failed workspace is diagnostic-only and is removed before the next attempt. Do not manually resume a failed Armbian tree.

Generated images and diagnostic bundles are written outside the repository under `~/opi5pro-images`.

V3.16 retains Snes9x first among native artifacts so the GCC 15/glslang compatibility gate is exercised before the long Stremio and emulator build sequence. It also validates generated launchers from artifact recipes and requires their destination directories before redirection. Do not reuse any earlier version's Armbian workspace or artifacts.

The builder does not touch the Orange Pi's installed NVMe. Storage migration is a post-validation, on-device operation and is outside image generation.
