# Storage lifecycle and migration

The storage plan is deliberately phased. Never combine phases merely to save time: each phase isolates a different boot/root variable and preserves a recovery path.

## Phase 0 — NVMe presence check

The installed NVMe may be checked now without changing it:

```bash
sudo opi-nvme-check
```

The helper enumerates devices with `lsblk` and reads SMART data with `nvme smart-log`. It does not mount, partition, format or write. Review model, serial, capacity, read-only state, critical warning, media/data-integrity errors, temperature and percentage used.

If the drive does not appear, stop there. Check seating, the board's M.2 connection, power and kernel logs. Do not create partitions merely to test detection.

## Phase 1 — development image entirely on SD

**Topology:** bootloader/boot/root on SD; NVMe unused.

This is the only approved topology while the image is still a development generation. It provides the simplest rollback: remove or reflash the test SD without risking another device.

Required proof before leaving this phase:

- fresh build and offline image QA complete;
- image checksum verified before and after flashing;
- multiple cold boots from SD;
- every hard gate in `VALIDATION.md`, including real Stremio and Moonlight hardware decoding;
- no unexplained systemd, filesystem, memory or thermal failures;
- validation report archived with the exact image manifest.

## Phase 2 — SD boot with Btrfs NVMe root

**Topology:** boot remains on SD; root filesystem lives on NVMe as Btrfs.

Use the image's installed `/usr/bin/armbian-install` interactively only after Phase 1 approval. Armbian's available menu wording can change; verify the displayed source and destination by model, serial and capacity before accepting any destructive action. Select the topology that keeps boot on SD and places the system/root filesystem on NVMe, choosing Btrfs when offered.

### Pre-migration checklist

- Retain the known-good SD image and its SHA-256.
- Copy irreplaceable user data elsewhere; migration is not a backup.
- Run `sudo opi-nvme-check` and record the device identity/health.
- Disconnect unrelated writable USB/SATA/NVMe devices to reduce target ambiguity.
- Use stable power and do not interrupt the installer.
- Confirm the installer is `/usr/bin/armbian-install` supplied by the built image.
- Confirm the selected target is the intended NVMe, never the SD card or an unrelated disk.

### Btrfs-specific behavior

At boot, `opi-ensure-swapfile` detects the root filesystem. On Btrfs it removes an incompatible prior swapfile and recreates the file with no-copy-on-write and compression disabled before allocation, matching Btrfs swapfile requirements. zram remains the high-priority first tier; disk swap is low-priority emergency capacity.

### Post-migration proof

After a full shutdown and cold boot:

```bash
findmnt -no SOURCE,FSTYPE,OPTIONS /
findmnt -no SOURCE,FSTYPE,OPTIONS /boot
lsblk -f
swapon --show
systemctl --failed
opi-validation-report
```

Confirm root is the intended NVMe Btrfs filesystem, boot remains on SD, zram and the Btrfs-valid swapfile are active, and all hardware gates still pass. Repeat several cold boots and at least one sustained media/emulator stress run.

## Phase 3 — eMMC boot with Btrfs NVMe root

**Topology:** bootloader/boot moves to eMMC; root remains on the already proven NVMe Btrfs filesystem.

Do not begin until eMMC is installed, Phase 2 is stable, the precise installer option is reviewed, and the SD remains available as rescue media. The objective is to change only the boot device; do not unnecessarily recreate the proven NVMe root.

After migration, first boot with all media present, verify eMMC supplies boot and NVMe supplies root, then power off and test a cold boot with the SD removed. Preserve the known-good SD card as recovery media even after it is no longer required for normal boot.

## Rollback strategy

- Phase 1 failure: reflash or replace the SD.
- Phase 2 boot failure: power off, preserve the NVMe, and use the known-good SD image to inspect logs/configuration. Do not immediately reformat the NVMe.
- Phase 3 boot failure: reinstall the known-good SD and confirm the NVMe root remains intact before changing bootloader state.
- At every phase, collect `journalctl -b`, `/boot/armbianEnv.txt`, `findmnt`, `lsblk -f` and the validation report before repair.

## Operations forbidden in the image builder

The repository's image-generation profile must not run `mkfs`, `wipefs`, `sfdisk`, `parted`, `nvme format`, mount an installed NVMe, copy a live root filesystem to it, or make assumptions from `/dev/nvme0n1` alone. `tools/check.sh` contains regression guards against these operations.

Storage migration is an explicit, attended, on-device operation because target selection and data destruction cannot be made safe by a generic build-host script.
