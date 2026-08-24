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
