---
name: linux-gaming-troubleshooting
description: Use when a game fails, crashes, or errors on Linux/Proton.
---

# Linux Gaming Troubleshooting

## Diagnostic Sequence

1. **Game process status**: `ps aux | grep -i <game>` — verify if game launched, check exit codes in Steam logs
2. **Steam logs**: `~/.steam/steam/logs/gameprocess_log.txt` and `console-linux.txt` — look for `exit code -1`, `ld.so` errors, vkd3d-proton errors
3. **GPU health**: `nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used --format=csv` — check VRAM, thermal throttling, OOM
4. **Kernel/driver**: `dmesg --level=err,warning --since "10 min ago"` — check for `NV_ERR_NO_MEMORY`, `rmStatus`, amdgpu errors
5. **Anti-cheat DNS**: `dig +short @1.1.1.1 <auth-server>` — verify anti-cheat auth servers resolve (see references/anti-cheat.md)
6. **Service files**: `systemctl cat <service>` + `ls /etc/systemd/system/<service>` — verify service files exist and paths are correct after repo reorganizations
7. **Proton version**: Check Steam → game Properties → Compatibility — verify correct Proton version selected
8. **Launch options**: Check Steam → game Properties → Launch Options — verify env vars for hybrid GPU

## Anti-Cheat Diagnostics

### Error 122 (GameGuard / nProtect)
- **Root cause**: GameGuard auth server returns NXDOMAIN — `dig api.gameguard.net @1.1.1.1` returns nothing
- **Secondary causes**: Corrupted GameGuard files, missing firewall ports, kernel.yama.ptrace_scope too high
- **Steam log pattern**: Game launches, all sub-processes exit with code -1 within seconds
- **See**: references/anti-cheat.md for full flow

### Error Codes Quick Reference
- `122` = GameGuard anti-cheat handshake failed (auth server unreachable)
- `0xc0000005` = Access violation in game.exe (often vkd3d-proton multi-GPU enum — check launch options for VK_ICD_FILENAMES and --use-d3d11 conflict)
- **Crash dump analysis**: 5/6 dumps showing 0xc0000005 confirms deterministic access violation — likely vkd3d-proton multi-GPU enum bug (Proton#7486). Check dump files in `compatdata/<appid>/pfx/.../Arrowhead/<game>/dumps/` for pattern consistency before tweaking settings.
- `exit code -1` = Process immediately killed (anti-cheat or missing dependency)

## Proton & GPU Configuration

### NVIDIA + Intel Hybrid (RTX 3050 laptop)
```
Launch Options: PROTON_ENABLE_NVAPI=1 VK_ICD_FILENAMES=nvidia_icd.json %command%
```
- Forces Vulkan to use NVIDIA ICD (relative path; Steam resolves to system ICD)
- Required for Proton Experimental multi-GPU enum workaround
- Enables NVAPI for ray tracing features
- **Pitfall**: `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json` (absolute path) can fail if Steam's runtime doesn't mount the host filesystem — use the short name and let Steam resolve it
- Add `DXVK_ASYNC=1 STEAM_SHADER_CACHE_MAXSIZE=536870912 STEAM_SHADER_CACHE_SIZE=536870912` for shader cache stability
- Remove `--use-d3d11` if present — it conflicts with vkd3d-proton's D3D11 implementation and causes 0xc0000005

### Proton Selection Priority
1. **Proton Experimental** — latest, best for most games, may have regressions
2. **GE-Proton** — community build, often better for anti-cheat (EAC/BattlEye), shader cache compatibility
3. **Steam Linux Runtime 4.0** — required dependency for all Proton versions

### 32-bit Libraries Required for Steam/Proton
lib32-libxtst, lib32-libxrandr, lib32-libxrender, lib32-libpulse, lib32-gdk-pixbuf2, lib32-libxi

## GameGuard Firewall Rules (iptables)
```bash
sudo iptables -I INPUT -p tcp --dport 28910:28919 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 28910:28919 -j ACCEPT
sudo iptables -I OUTPUT -p tcp --dport 28910:28919 -j ACCEPT
sudo iptables -I OUTPUT -p udp --dport 28910:28919 -j ACCEPT
```
GameGuard (nProtect) uses ports 28910:28919 for auth handshake.

## In-Game Monitoring Sources

### Steam Built-in Monitoring
- `game_frame_rate_reporting: 2` in `cachedStorePreferences` (config.vdf) enables Steam's frame time tracking. Cosmetic perf impact.
- Steam overlay adds ~1-3% GPU overhead. Disable per-game if benchmarking.
- `PROTON_LOG=1` in launch options generates 100M+ log files. Remove after debugging to prevent disk bloat.

### External Monitors That Interfere With Gaming
Check and optionally stop these before gaming:
- `/home/sin/.local/bin/gpu-watchdog` — failover watchdog (safe; only acts on XID events, no idle overhead)
- `/home/sin/miners/steam-pause-watcher.sh` — pauses miners on Steam start (safe; no overhead once miners paused)
- `/usr/local/bin/satellite-detect monitor` — network interface monitor (low overhead; safe)
- `plasma-systemmonitor` — KDE system monitor UI (closes cleanly, frees ~120MB)
- `gdbus monitor` — KDE panel colorizer watches (safe; cosmetic only)
- `auditd` — kernel audit daemon (safe; kernel-level, userspace daemon is low overhead)

**Decision**: gpu-watchdog and steam-pause-watcher are *beneficial* during gaming (they protect and free resources). Don't disable unless chasing every last frame.

## Pitfalls

- **Anti-cheat servers can be dead (external)**: `api.gameguard.net`, `update.gameguard.net`, `gg.plaync.co.kr` returning NXDOMAIN means the anti-cheat infrastructure is offline. Not fixable locally — verify with `dig` before wasting time on local configs. If dead, game will fail to launch regardless of Proton/GPU/kernel settings.
- **Corrupted GameGuard files**: Old `GameGuard.des` and `GameGuard/` folder in game's bin directory can cause handshake failures. Try renaming `GameGuard.des` → `GameGuard.des.disabled` directory first (preserves file for Steam re-download); delete only if the `.disabled` approach doesn't work. Then "Verify integrity of game files".
- **GameGuard.des.disabled bypass**: If nProtect auth hangs (Error 122) even with valid GameGuard files, create `GameGuard.des.disabled/` directory in the game's `DATA/Win64/` path — some nProtect versions check for this directory and skip auth when present.
- **Garuda security hardening blocks anti-cheat**: `kernel.yama.ptrace_scope=3` in Garuda's 99-security-hardening.conf cannot be lowered at runtime. Setting it in 99-gameguard.conf is overridden by the security-hardening load order. Anti-cheat that needs ptrace (EAC, BattlEye) may fail.
- **Steam launches via runtime wrapper**: Always start Steam via `/usr/bin/steam` wrapper, not the raw steam binary, to get the runtime environment. Missing 32-bit libs break Steam UI (steamui.so dlmopen failure).
- **Repo reorganizations break service files**: When repos are reorganized, systemd service files at `/etc/systemd/system/` may be deleted but the underlying scripts remain in the repo. Always check `systemctl cat <service>` and search the repo for the `.service` file before assuming it's never existed.
- **Service WorkingDirectory paths**: After repo moves, `WorkingDirectory=` in service files often points to deleted paths. The service fails with "Failed at step CHDIR" in journal. Fix the path in the service file, not just re-enable.
- **Ollama needs log dir**: `/var/log/ollama` is not created by default. If missing, ollama.service fails with "Failed to set up mount namespacing: /var/log/ollama: No such file or directory". Create with `sudo mkdir -p /var/log/ollama && sudo chown ollama:ollama /var/log/ollama`.
- **dnscrypt-proxy changes resolv.conf**: If `/etc/resolv.conf` points to the router (10.128.128.128) instead of dnscrypt-proxy (127.0.2.1), anti-cheat auth servers may not resolve. Set `nameserver 127.0.2.1` in resolv.conf.
- **OpenXR init failure**: `OpenXR: Unable to get required Vulkan Device extensions size` in Steam logs is cosmetic — VR is not needed for flat-screen play.
- **GameOverlayRenderer preload errors**: `wrong ELF class: ELFCLASS32/ELFCLASS64` from LD_PRELOAD are cosmetic — Steam overlay still works.
- **Shader cache stuttering**: First 30-60 seconds after launching a new game will stutter as shaders compile. Wait before concluding the game is broken. Use `PROTON_DUMP_DEBUG_COMMANDS=1` to pre-cache if needed.
- **32-bit Vulkan ICD missing**: `ldconfig -p | grep libvulkan.so.1` showing only 64-bit paths means 32-bit Proton games fall back to lavapipe (software rendering). Install 32-bit Vulkan loader: copy `/usr/share/vulkan/icd.d/nvidia_icd.json` to `/usr/lib32/vulkan/` and ensure `libvulkan.so.1` resolves for i686.
- **Orphan compatdata prefixes**: Game prefixes without matching appmanifest in `steamapps/` waste disk space and can cause Steam to misidentify installations. Clean with `rm -rf steamapps/compatdata/<appid>/` only when no matching appmanifest exists.
- **Missing game binaries**: Empty game directories (no .exe, no linux binary) with valid appmanifest indicate interrupted downloads or corrupted installs. Steam's "Verify integrity of game files" fixes partial cases; full reinstall for empty directories.
- **Native Linux games with 32-bit binaries**: Games like Undertale ship 32-bit ELF executables. Require full 32-bit library stack (`lib32-libX11`, `lib32-libglvnd`, `lib32-alsa-lib`, `lib32-libpulse`, `lib32-gdk-pixbuf2`, `lib32-libxi`, `lib32-libxrandr`, `lib32-libxrender`, `lib32-libxtst`) even when 64-bit libs are present.
- **RuneScape launcher architecture**: `rs2client.exe` is the actual game binary, not a stub. If `bin/win64/` is empty, the launcher downloads game files from CDN — verify launcher can reach `content.runescape.com` and `www.runescape.com` through DNS/proxy before blaming Proton.
