<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: waydroid-arch-debug
description: "Diagnose Waydroid on Arch/Garuda and draft upstream reports."
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [waydroid, arch, linux, container, debug]
---

# Waydroid on Arch/Garuda Debug

Use when setting up, repairing, diagnosing, or reporting Waydroid issues on Arch-based systems. Covers init/container issues, HAL missing errors, `IP address: UNKNOWN`, cgroup readonly errors, `rust_binder` ENOSPC regressions, and upstream report drafting.

## When to Use

- Install, init, start, or fix Waydroid
- Container won't stay RUNNING or session stays STOPPED
- Audio HAL missing or init HAL failures
- `waydroid status` shows `IP address: UNKNOWN`
- dmesg shows `Read-only file system` on `/sys/fs/cgroup`
- dmesg shows `rust_binder` ENOSPC/large-transaction failures
- Draft upstream bug reports for Arch/Garuda/upstream

## Prerequisites

- Waydroid installed: `pacman -Qs waydroid`
- LXC installed: `pacman -Qs lxc`
- Sudo privileges for container/firewall inspection
- Kernel config access: `/proc/config.gz` or `/usr/lib/modules/*/build/.config`

## Procedure

### 1. Status Triage

Start with live state:

```
terminal(command="waydroid status 2>/dev/null || true")
terminal(command="sudo lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH 2>/dev/null || true")
terminal(command="sudo systemctl status waydroid-container --no-pager 2>/dev/null | head -20 || true")
terminal(command="sudo cat /var/lib/waydroid/waydroid.log 2>/dev/null | tail -40 || true")
terminal(command="sudo dmesg --level=err,warn | tail -20 || true")
```

### 2. Issue Routing

Read the matching reference before changing anything:

| Symptom | Reference |
|---|---|
| Missing HAL / init errors | `references/missing-hal.md` |
| cgroup readonly / createProcessGroup failures | `references/cgroup-delegation.md` |
| `IP address: UNKNOWN` / DHCP blocks | `references/network-dhcp.md` |
| `rust_binder` ENOSPC on kernel >= 6.18 | `references/rust-binder-regression.md` |
| Upstream report formatting | `references/upstream-reports.md` |
| Steam/Proton game drive errors | `references/steam-proton-game-drive.md` |
- Shader pipeline / game build issues | `references/shader-pipeline-autoconfig.md`

### 2.5 Kernel Fix Shortcut (rust_binder ENOSPC)

**CRITICAL LEARNED PATH**: Before attempting a custom kernel rebuild, check if the Arch repo kernel already contains the fix. On Arch >= 7.2.3, `linux-zen` ships with commit `8e28c67` (the `PointerFixupEntry` enum fix). The common trap: `uname -r` shows an older version while `pacman -Q linux-zen` shows the newer one — the package is installed but the host hasn't rebooted. In this case, `pacman -Syu linux-zen linux-zen-headers` + reboot is the fix. No custom rebuild needed.

Only proceed to a custom rebuild if `pacman -Q linux-zen` still shows a version that lacks the fix (very unlikely on current Arch).

### 2.6 Waydroid GAPPS Install

**Pitfall**: `pacman -S waydroid-image-gapps` fails with "unable to lock database" if a stale pacman process is running.

Fix:
```bash
# Kill any stale pacman and remove lock
sudo kill $(pgrep -f 'pacman.*waydroid') 2>/dev/null
sudo rm -f /var/lib/pacman/db.lck

# Install with --overwrite if system.img/vendor.img already exist from a prior install
sudo pacman -S waydroid-image-gapps --noconfirm --overwrite '/usr/share/waydroid-extra/images/*'

# Initialize GAPPS after install
sudo waydroid init --system_type GAPPS --force
sudo systemctl start waydroid-container.service
```

⚠️ **Session start without GUI**: `waydroid session start` fails with D-Bus/X11 errors on headless CLI. The container service runs independently — verify with `sudo systemctl status waydroid-container.service` and `sudo lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH`. A GUI session (KDE/GNOME) is required for the full session manager.

⚠️ **Conflicting files**: if the package reports `/usr/share/waydroid-extra/images/system.img` and `vendor.img` already exist, use `--overwrite` flag or remove the files first.

### 3. Safety Rules

- Do not apply patches unless the reference explicitly marks them safe.
- Back up before editing: `sudo cp <path> <path>.bak`.
- Revert firewall/LXC changes if verification fails.
- Do not claim a kernel path is fixed without inspecting that exact kernel `.config`.
- If a fix is theoretical/untested, present it as a workaround, not a resolved issue.
- Steam shader cache path is `~/.local/share/Steam/steamapps/shadercache/` NOT `~/.steam/steam/shadercache/` — the script's `SHADER_CACHE` path must match what Steam actually writes to, or caches build in an empty directory Steam never reads.

### 4. Auto-Config Scripts (Shader Pipeline & Game Cache)

When game shader pipelines or Steam Proton shader cache need setup/repair:

- Scripts live at `~/games/waydroid-issues/scripts/`:
  - `auto_config.sh` — bash auto-configurator with self-healing (diagnose/heal/recode/full modes)
  - `self_debug.py` — Python wrapper with GameProfile, diagnostics, healing, crash monitoring, self-recode
  - `shader_cache_manager.py` — Proton shader cache manager with auto-config, self-healing, game adaptation
- Run `bash auto_config.sh <game> [mode]` for local game builds (2ship2harkinian, twilight-elysium, loz-majoras-mask)
- Run `python3 shader_cache_manager.py <game> --diagnose|--heal|--launch` for Steam/Proton shader cache
- Run `python3 self_debug.py <game> --diagnose|--heal|--launch|--status` for full launch cycle with crash monitoring
- Auto-config adapts per-game: detects stale CMake caches (Projects/ path mismatches), missing shared libs, missing shader assets, and regenerates build files
- Self-debug wrappers record crashes and learned preferences per game for future sessions
- State persists to `.auto_config_state` and `self_debug_profiles.json`
