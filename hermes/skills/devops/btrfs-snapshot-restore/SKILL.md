---
name: btrfs-snapshot-restore
description: Create, pin, prune, and restore from btrfs snapper snapshots on Garuda/Arch via the snapgood tool.
---

# Btrfs Snapshot Management

All snapshot work on this host goes through `snapgood`
(`/usr/local/sbin/snapgood`). Do not call `btrfs subvolume snapshot`
directly, and do not write raw subvolumes into `/.snapshots` — that creates
snapshots snapper cannot see and no cleanup rule can reach.

## Retention policy

- **10 unpinned snapshots**, newest first.
- **Pinned snapshots are exempt**, on top of the 10, never auto-deleted.
- Never pruned: pinned, currently mounted, or unverifiable (UUID drift,
  missing). The tool keeps such a snapshot and explains why rather than
  deleting what it cannot prove it understands.
- Hard floor: 2 unpinned snapshots always survive, plus 1 per snapper config.
- `prune` is a dry run unless `--yes` is given.

## Pinning a known-good boot

A snapshot is only kept because you say it boots. Do this after a rebuild or
update you have verified:

```bash
sudo snapgood list                                   # find it
sudo snapgood pin 42 --note "rebuild 2026-10-01 verified, boots clean"
sudo snapgood unpin 42                               # release
```

Pinning also marks the snapshot `important` inside snapper, so snapper's own
cleanup will not reap it either.

## Checking a candidate actually boots

```bash
sudo snapgood verify 42 --boot-entry
```

Confirms the subvolume exists, is read-only, is boot-shaped (`etc`, `usr`,
`boot`), its UUID is stable, and that it appears in
`/boot/grub/grub-btrfs.cfg`.

## Day-to-day

```bash
snapgood status                      # inventory, budget, over/under by how much
snapgood list                        # all snapshots, pin state, age
snapgood create -d "before upgrade"  # create
sudo snapgood prune                  # dry run: shows exactly what would go
sudo snapgood prune --yes            # enforce
```

Adopting the pre-snapgood raw subvolumes in `/.snapshots`:

```bash
sudo snapgood adopt      # register legacy subvolumes
sudo snapgood prune      # dry run
sudo snapgood prune --yes
```

## Layout

- Snapper-managed: `/.snapshots/<config>/<number>/snapshot/`
- Adopted raw subvolumes: `/.snapshots/<name>/` (direct children)
- Pin registry: `/var/lib/snapgood/registry.json`
- Prune audit log: `/var/log/snapgood/prune.log`
- Retention: `/usr/local/sbin/snapgood`, timer `snapgood-prune.timer`
  (daily, advisory/dry-run)

Snapper creates snapshots but does not prune them; snapgood owns retention.

## Bootloader safety

Two grub settings are deliberately unchanged on this host:

- `GRUB_BTRFS_ENABLE_CRYPTODISK` stays commented out. grub-btrfs implements it
  via `cryptomount -u <uuid>` scraped from `cryptdevice=UUID=...:cryptdev=`,
  which this dracut-style `rd.luks.uuid=` cmdline does not contain. Enabling it
  yields `cryptomount -u ` with an empty argument, which passes
  `grub-script-check` and fails only at boot. `GRUB_ENABLE_CRYPTODISK=y` in
  `/etc/default/grub` already handles the unlock.
- `GRUB_DEFAULT=0`, never `saved`. All grub-btrfs snapshot entries share one
  `menuentry_id_option`, so `save_env` cannot distinguish them and a remembered
  entry can outlive its snapshot.

Before any reboot after changing snapshot state:

```bash
sudo check-boot-entry.sh   # confirms GRUB entry 0 is the live root, not a snapshot
sudo audit.sh               # bootloader, retention, btrfs health
```

`/boot` is not a separate mount here; it lives inside `@`. Each snapshot copies
the kernel and both initramfs files (~309M before compression), so retention has
a real cost on this box.

## Pinning vs booting

`snapgood pin` records a verified snapshot as known-good and exempt from
retention. It does not make GRUB boot it. Booting a snapshot is a deliberate
choice from the GRUB submenu; entry 0 always stays the live system.

## Restoring

Single file or directory out of a snapshot:

```bash
sudo snapgood verify 42
sudo snapgood restore 42 --path etc/pacman.conf --to /etc/pacman.conf
```

Whole-system rollback (needs root, reboots to finish):

```bash
sudo snapgood restore 42
```

Mount a snapshot read-only to browse it first:

```bash
sudo mount -o ro,subv=/.snapshots/42/snapshot /dev/mapper/luks-* /mnt
```

## Pattern: removing packages via update

1. `snapgood list` — find the snapshot just before the `pacman -Su`.
2. Pin it, so cleanup cannot remove it mid-recovery:
   `sudo snapgood pin <num> --note "pre-pacman -Su recovery point"`.
3. Reinstall: `sudo pacman -S --noconfirm --needed <pkg>...`
4. Restore configs from that snapshot.
5. Verify: `pacman -Q <pkg>`, `systemctl status <svc>`, `ss -tlnp`.
6. Unpin and prune when satisfied.

## Safety

- Never restore `/etc/NetworkManager/system-connections/` if the user wants to
  keep current network configs.
- `/home` is its own subvolume (`@home`) with its own snapper config; root
  snapshots do not cover it. Restore home from the `home` config.
- Do not delete the only snapshot of a subvolume. `snapgood prune` refuses this,
  but manual `btrfs subvolume delete` will not.
- After pruning, GRUB's snapshot menu is regenerated. If a snapshot is missing
  from the boot menu, run `sudo grub-btrfsd`.
