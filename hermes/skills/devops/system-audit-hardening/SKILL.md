---
name: system-audit-hardening
description: Use when auditing and hardening an Arch/Garuda Linux system.
---

# System Audit & Hardening

## Audit Checklist (run in this order)

1. **Disk**: `df -h /` — flag if >85%
2. **Services**: `systemctl list-units --failed` + `journalctl -p err --since "1 hour ago"` — filter noise (powerdevil, plasmashell, kwin)
3. **Listeners**: `ss -tlnp` — flag anything bound to 0.0.0.0 besides expected; use `sudo ss -tulpn` for full TCP+UDP; see `arch-system-hardening/references/network-listeners.md` for the expected listener table
4. **Orphans**: `pacman -Qdtq` — remove with `pacman -Rns`
5. **AUR packages**: `pacman -Qmq` — review foreign packages, decide keep/remove
6. **Config errors**: check journal for config parsing failures (NM, dirmngr, systemd)
7. **Package manager**: `checkupdates` + `pacman -Qu` — pending updates
8. **Snapshots**: `snapper list` — verify recent snapshot exists before making changes
9. **Localhost pentest sweep**: `sudo ss -tulpn`, `find / -xdev -type f \( -perm -4000 -o -perm -2000 \)`, `getcap -r / 2>/dev/null | grep -v snapshots`, `sudo nmap -sS -sU --top-ports 1000 -T4 127.0.0.1` — identify all localhost services and their owning PIDs; cross-reference against the expected listener table. Any unexplained listener = investigate.

## Fix Sequence

1. Remove orphans first (frees space, reduces attack surface)
2. Clean pacman cache: `sudo pacman -Sc` then `sudo pacman -Scc`
3. **ENOSPC recovery** (disk full, app crashes with "no space left"): see procedure below
4. Fix config errors found in journal
5. Enable/fix services: `sudo systemctl enable --now <service>`
6. Clear stale sockets: `sudo rm -f /etc/pacman.d/gnupg/S.*` (dirmngr conflicts)
7. Fix file ownership: `sudo chown -R user:group /var/lib/<service>/`
8. Run `sudo updatedb` after permission fixes
9. Create snapshot before major changes: `sudo snapper create -c root -t single -d "description"`

## ENOSPC Recovery (disk full → app crash)

When an Electron/Node app crashes with `ENOSPC: no space left on device`:

1. Confirm: `df -h /home /` — identify the full partition
2. Find space hogs: `sudo du -x -h --max-depth=1 /home/sin | sort -rh | head -20`
3. Clean pacman cache: `sudo pacman -Sc --noconfirm` then `sudo pacman -Scc --noconfirm`
4. Remove stale download dirs pacman -Scc leaves behind: `sudo rm -rf /var/cache/pacman/pkg/download-*`
5. Vacuum journals: `sudo journalctl --vacuum-size=50M`
6. List snapshots: `sudo snapper list` (non-root returns "No permissions")
7. Clear stale app config that blocks clean restart: `rm -rf /home/sin/.config/garuda-toolbox/`
8. Verify free space: `df -h /home`
9. Retry the app

## Pitfalls

- **snapper needs root**: `sudo snapper create` required; non-root sessions can't create snapshots; `snapper list` without sudo returns "No permissions"
- **pacman -Scc prompts twice**: use `--noconfirm` or pipe `yes |`; but `pacman -Scc` does NOT clean `download-*` subdirs in `/var/cache/pacman/pkg/` — must `sudo rm -rf /var/cache/pacman/pkg/download-*` separately
- **plocate static timer**: timer may be static (not enabled); manual `updatedb` works but timer needs fstab fix if /var/lib/plocate is read-only
- **AUR packages**: `pacman -Qmq` shows foreign packages; review before removing — some may be intentionally installed
- **NVIDIA out-of-tree**: `nvidia` module loaded = out-of-tree, taints kernel; not fixable via pacman
- **dirmngr socket conflicts**: stale S.dirmngr, S.gpg-agent.* sockets cause "Address already in use"; remove and restart
- **NM privacy config**: `new-cloned-mac-address` is invalid key; use `mac-address-seeded` or `wifi.cloned-mac-address`
- **firewalld rich rules override zone config**: rich rules for DROP (port, MAC, source) persist independently of zone settings. A DROP on port 1716 will block KDE Connect even though the zone allows it. Always check `firewall-cmd --list-rich-rules` alongside `--list-all` before troubleshooting listener access.
- **Zen Suite vulkan-shader-cache pipeline**: the service expects a permutations JSON at the path compiled into the JS at build time. The install script copies `.ts` to `.js` but the standalone JS must reference the correct path (the install script hardcodes `/home/sin/zen-suite/` but the actual source may live at `/home/sin/zen/linux-zen-suite/`). After install, verify the JS loads variants with `journalctl -u zen-vulkan-shader-cache -n 5` — "Loaded 0 shader variants" means path mismatch or wrong JSON shape. The JSON must use `"variants"` key (not `"permutations"`), each with `shader`, `entrypoint`, `stage`. Also ensure the `zen` user can traverse the entire path (parent dirs need +x for non-owners).
- **Root-owned daemon from user venv is a red flag**: a process running as root but executing from a user-owned venv path (e.g. `/home/sin/workspace/.venv/bin/python /opt/bde/...`) is a privilege mismatch. Verify the binary has no network egress (check `lsof -p <pid>` and `/proc/<pid>/net/tcp`), no external HTTP imports, and communicates only over Unix-domain sockets before trusting it.
- **Disk >85% on btrfs = performance cliff**: BTRFS slows dramatically past 80% usage. Clean pacman cache (`sudo pacman -Sc`) and trash before investigating other issues — many audit findings (plocate failures, permission errors) are secondary to a full filesystem.
- **garuda-toolbox stale config after ENOSPC**: when ENOSPC crashes garuda-toolbox, the partially-written config.json blocks clean restart — delete `/home/sin/.config/garuda-toolbox/` and let it rebuild on next launch.

## Pitfalls

- **snapper needs root**: `sudo snapper create` required; non-root sessions can't create snapshots
- **pacman -Scc prompts twice**: use `--noconfirm` or pipe `yes |`
- **plocate static timer**: timer may be static (not enabled); manual `updatedb` works but timer needs fstab fix if /var/lib/plocate is read-only
- **AUR packages**: `pacman -Qmq` shows foreign packages; review before removing — some may be intentionally installed
- **NVIDIA out-of-tree**: `nvidia` module loaded = out-of-tree, taints kernel; not fixable via pacman
- **dirmngr socket conflicts**: stale S.dirmngr, S.gpg-agent.* sockets cause "Address already in use"; remove and restart
- **NM privacy config**: `new-cloned-mac-address` is invalid key; use `mac-address-seeded` or `wifi.cloned-mac-address`
- **firewalld rich rules override zone config**: rich rules for DROP (port, MAC, source) persist independently of zone settings. A DROP on port 1716 will block KDE Connect even though the zone allows it. Always check `firewall-cmd --list-rich-rules` alongside `--list-all` before troubleshooting listener access.
- **Zen Suite vulkan-shader-cache pipeline**: the service expects a permutations JSON at the path compiled into the JS at build time. The install script copies `.ts` to `.js` but the standalone JS must reference the correct path (the install script hardcodes `/home/sin/zen-suite/` but the actual source may live at `/home/sin/zen/linux-zen-suite/`). After install, verify the JS loads variants with `journalctl -u zen-vulkan-shader-cache -n 5` — "Loaded 0 shader variants" means path mismatch or wrong JSON shape. The JSON must use `"variants"` key (not `"permutations"`), each with `shader`, `entrypoint`, `stage`. Also ensure the `zen` user can traverse the entire path (parent dirs need +x for non-owners).
- **Root-owned daemon from user venv is a red flag**: a process running as root but executing from a user-owned venv path (e.g. `/home/sin/workspace/.venv/bin/python /opt/bde/...`) is a privilege mismatch. Verify the binary has no network egress (check `lsof -p <pid>` and `/proc/<pid>/net/tcp`), no external HTTP imports, and communicates only over Unix-domain sockets before trusting it.
- **Disk >85% on btrfs = performance cliff**: BTRFS slows dramatically past 80% usage. Clean pacman cache (`sudo pacman -Sc`) and trash before investigating other issues — many audit findings (plocate failures, permission errors) are secondary to a full filesystem.