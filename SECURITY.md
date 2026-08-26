# Security policy

## Scope

This project builds an appliance-style Linux image from Armbian, Ubuntu and pinned third-party sources. Security reports may concern repository scripts, source verification, credential exposure, unsafe image defaults, privilege boundaries, browser repositories, update policy or destructive storage behavior.

## Reporting

Do not publish exploitable details, credentials or private hardware identifiers in a public issue. Use GitHub's private security-advisory facility for this repository when available, or contact the repository owner privately. Include the affected commit/version, reproduction steps, impact and the smallest safe diagnostic evidence.

## Secrets and private material

Never commit or attach:

- account passwords or hashes;
- GitHub/API tokens, SSH private keys or browser credentials;
- Wi-Fi credentials or Bluetooth keys;
- ROMs, copyrighted BIOS/firmware or decryption keys;
- unreviewed logs containing personal paths, serials or tokens.

The build reads the image account password from `/dev/tty`, hashes it immediately and does not intentionally log plaintext.

## Supply-chain model

- Mandatory source tags/branches are resolved to commits.
- Built checkout commits and downloaded artifact hashes are recorded.
- Browser repositories are bound to official HTTPS sources and audited signing-key fingerprints.
- Network operations are bounded and non-interactive.
- Mandatory build/install/runtime gates fail closed.
- Generated images are not committed to Git and must be distributed with a checksum and build manifest.
- Persistent downloads require a matching SHA-256 sidecar, and reviewed digest pins remain authoritative over cache metadata.
- The dependency image is keyed by the pulled ARM64 base content ID, build-package manifest and schema, then revalidates architecture and package presence on every use.
- Native compiler caching uses content-based compiler identity and per-application namespaces. Cache entries never replace source-lock, linkage, target-root or raw-image checks.
- The persistent Armbian mirror is restricted to the official origin, refreshed through bounded Git transport, connectivity-checked and copied into a new detached checkout for every build.

A pin is not a guarantee that upstream content is safe. Review upstream security advisories and changes before updating or rebuilding for distribution.

## Runtime defaults

- Security-only unattended upgrades are enabled.
- Automatic reboot is disabled.
- SSH server/socket are disabled by default; the client remains installed.
- The local `ryan` account has the password chosen at build time and limited passwordless commands needed for session/power appliance controls.
- Browser and network-facing application security remains dependent on timely upstream/Ubuntu updates.
- `opi-update` permits attended same-release APT upgrades only, refuses non-ARM64/non-Orange-Pi-5-Pro/non-Resolute hosts, serializes runs, simulates first, records package inventories and runs post-update health checks.
- Distribution upgrades are disabled. Image-managed source builds are not silently replaced by APT; they remain pinned pending a signed project-bundle channel.

## Storage safety

Before image finalization, installed NVMe access is read-only inventory/SMART. The builder must never mount, partition, format or migrate it. Storage migration is attended and destructive; follow `docs/STORAGE.md`, verify device identity and keep recovery media.

## Supported security state

Only an image tied to a known repository commit, successful build/offline QA and completed hardware validation can be treated as a supported candidate. Steam ARM64 and GE-Proton are experimental and should not be trusted as a hardened application boundary.
