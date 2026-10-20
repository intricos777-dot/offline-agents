<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
# Session 2026-09-04: Waydroid Kernel & Steam Fixes

## Summary
Fixed Waydroid rust_binder ENOSPC regression and Steam Once Human launch failures on Garuda Linux (linux-zen 7.2.x).

## Key Findings

### 1. Kernel Fix Already Present
- `uname -r` showed `7.2.2-zen1-1-zen` (running)
- `pacman -Q linux-zen` showed `7.2.3.zen1-2` (installed)
- The repo kernel `7.2.3.zen1-2` already contains upstream commit `8e28c67` (PointerFixupEntry enum fix for rust_binder zero-length FDA bug)
- **Fix**: `pacman -Syu linux-zen linux-zen-headers` + reboot — no custom rebuild needed
- Verified: `dmesg | grep -iE 'error|fail|binder|ENOSPC'` returns 0 errors after reboot

### 2. Steam Once Human Launch Failure
Two issues found in `~/.steam/logs/console-linux.txt`:

**a) Wine prefix libraryfolders.vdf pointed to `S:\\`**
- File: `~/.local/share/Steam/steamapps/compatdata/2139460/pfx/drive_c/Program Files (x86)/Steam/steamapps/libraryfolders.vdf`
- Fix: Replace `S:\\` with `C:\\Program Files (x86)\\Steam`

**b) Stale gameoverlayrenderer.so LD_PRELOAD mismatch**
- Both `/ubuntu12_32/gameoverlayrenderer.so` and `/ubuntu12_64/gameoverlayrenderer.so` had wrong ELF class
- Fix: `rm -f ~/.local/share/Steam/ubuntu12_*/gameoverlayrenderer.so`
- Steam redownloads correct binaries on next launch

### 3. GRUB Fallback Default
- Set `GRUB_DEFAULT="Advanced options for Garuda Linux>Garuda Linux, with Linux linux-zen (fallback initramfs)"` in `/etc/default/grub`
- Run `grub-mkconfig -o /boot/grub/grub.cfg`
- Provides safe boot target if new kernel causes issues

### 4. OpenCode Investigation
- OpenCode session `ses_f9158d7c7ffezopL2xDs40hyyK` was investigating SurfaceFlinger composer HAL roundtrip issue
- SurfaceFlinger (PID 138296) and composer HAL (PID 138280) were both running
- OpenCode hit a billing error on secondary session but main build session remained active
- The `wlhello` C test program was compiled to test Wayland socket roundtrip

## Verification Commands
```bash
# Check if repo kernel has the binder fix
pacman -Q linux-zen
zcat /var/cache/pacman/pkg/linux-zen-*.pkg.tar.zst 2>/dev/null | tar -xO usr/src/linux-*/drivers/android/binder/thread.rs 2>/dev/null | grep -c 'PointerFixupEntry::Fixup'

# After reboot, verify no binder errors
dmesg | grep -iE 'error|fail|binder|ENOSPC' | wc -l

# Check Steam fixes
cat ~/.local/share/Steam/steamapps/compatdata/2139460/pfx/drive_c/Program\ Files\ \(x86\)/Steam/steamapps/libraryfolders.vdf
ls ~/.local/share/Steam/ubuntu12_*/gameoverlayrenderer* 2>&1 | wc -l
```

## Files Changed
- `/etc/default/grub` — GRUB default set to fallback initramfs
- `~/.local/share/Steam/steamapps/compatdata/2139460/pfx/drive_c/Program Files (x86)/Steam/steamapps/libraryfolders.vdf` — fixed S:\ path
- `~/.local/share/Steam/ubuntu12_32/gameoverlayrenderer.so` — removed
- `~/.local/share/Steam/ubuntu12_64/gameoverlayrenderer.so` — removed
- `linux-zen` upgraded from 7.2.2.zen1-1-zen to 7.2.3.zen1-2
- `linux-zen-headers` upgraded to 7.2.3.zen1-2

## Notes
- Waydroid IP UNKNOWN is a known issue (dnsmasq lease file empty) — non-fatal
- Missing `vendor.audio-hal-2-0` is a known upstream image bug
- No ashmem module loaded — binderfs works without it on rust_binder
- `/boot/grub/grub.cfg` is symlinked to `/boot/grub/grub.cfg` via bootloader
