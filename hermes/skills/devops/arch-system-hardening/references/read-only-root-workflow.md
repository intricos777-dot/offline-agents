<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
# Read-Only Root Recovery

## Symptom

`systemctl` writes fail, `pacman -Syu` rejects transactions, `auditctl -R` silently fails,
`plocate.timer` fails with `Read-only file system`.

## Diagnosis

```bash
mount | grep "on / "              # look for subvol=@/.snapshots/<N>/snapshot
btrfs subvolume show /             # check readonly flag
sudo btrfs subvolume list / | grep '@$'
```

If the root mount shows a snapshot path (not `subvol=@`), the system is in a readonly snapshot.

## Recovery

```bash
sudo btrfs subvolume set-default <@-subvolid> /
# Reboot required — current session stays readonly
```

After reboot:
```bash
mount | grep "on / "              # should show subvol=@
touch /tmp/test                    # should succeed
sudo systemctl start tor.service   # should work
```

## Notes

- `@` subvolume ID is typically 256 — confirm with `btrfs subvolume list / | grep 'path @$'`
- Snapshot grub.cfg is stale; the live `@` subvolume's `/boot/grub/grub.cfg` is the working one
- `grub-btrfs` plugin auto-generates snapshot boot entries into `grub-btrfs.cfg`
- Do NOT try to write to `/boot` or `/var/lib` before fixing the default subvolume
