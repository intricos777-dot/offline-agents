---
name: btrfs-snapshot-restore
description: Restore files from btrfs snapper snapshots on Garuda/Arch.
---

# Btrfs Snapshot Restore

## Prerequisites
- System uses btrfs with snapper (Garuda Linux default)
- Root subvolume at `@` with `.snapshots` directory
- User subvolumes: `@home`, `@root`, `@cache`, etc.

## Key Commands

### List all snapshots
```bash
sudo snapper list
btrfs subvolume list /
```

### Access snapshot contents
Snapshots are mounted at `/.snapshots/<num>/snapshot/`
- Pre-snapshot: `/.snapshots/<pre_num>/snapshot/`
- Post-snapshot: `/.snapshots/<post_num>/snapshot/`
- Named snapshot: `/.snapshots/<name>/snapshot/`

### Restore a config file from snapshot
```bash
sudo cp /.snapshots/<num>/snapshot/etc/<config> /etc/<config>
```

### Reinstall removed packages
```bash
sudo pacman -S --noconfirm --needed <packages>
```
Then restore configs from the snapshot taken just before removal.

## Pattern: Package Removal via Update
1. Find the snapshot just before the `pacman -Su` that removed packages
2. Reinstall packages: `pacman -S --noconfirm --needed <pkg1> <pkg2>...`
3. Restore configs from the pre-removal snapshot
4. Create new snapshots (snapper auto-creates pre/post for pacman)

## Notes
- `diff -rq /.snapshots/<num>/snapshot/etc/<dir> /etc/<dir>` compares snapshot vs current
- The `@_backup_YYYY-MM-DDTHH:MM:SSZ_stable` subvolume is a backup of the root subvolume
- Home directory files are in `@home` subvolume, accessible via `/.snapshots/<num>/snapshot/home/sin/`
- Never restore `/etc/NetworkManager/system-connections/` if user wants to preserve network configs

## Safety
- Always verify package versions match before/after
- Check `pacman -Q <pkg>` after reinstall
- Verify service status with `systemctl status <service>`
- Confirm listening ports with `ss -tlnp`
