<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: anti-cheat
description: Anti-cheat (GameGuard/nProtect, EAC, BattlEye) diagnostic flow and workarounds
---
# Anti-Cheat Diagnostics

## Error 122 (GameGuard / nProtect)

### Root Cause
GameGuard auth server returns NXDOMAIN — `dig api.gameguard.net @1.1.1.1` returns nothing. Anti-cheat infrastructure is offline. Not fixable locally.

### Secondary Causes (in order of likelihood)
1. DNS resolution failure — dnscrypt-proxy or Tor in network path blocks auth servers
2. Corrupted GameGuard files — old `GameGuard.des` or `GameGuard/` folder causes handshake failure
3. Missing firewall ports — GameGuard uses 28910:28919 TCP/UDP
4. kernel.yama.ptrace_scope too high — Garuda's 99-security-hardening.conf sets ptrace_scope=3, overridden by 99-gameguard.conf
5. nProtect auth hang even with valid GameGuard files — some nProtect versions check for `GameGuard.des.disabled/` directory and skip auth when present

### Diagnostic Sequence
1. `dig +short @1.1.1.1 api.gameguard.net` — verify auth server resolves
2. `systemctl status gameguard-network.service` — verify firewall rules active
3. Check `~/.local/share/Steam/steamapps/common/<game>/game/DATA/Win64/` for GameGuard.des and GameGuard/ folder
4. `cat /etc/hosts | grep gameguard` — verify no localhost bypass causing auth hang
5. Check kernel.yama.ptrace_scope: `cat /proc/sys/kernel/yama/ptrace_scope`

### Fixes
- **Auth server dead (NXDOMAIN)**: Wait for upstream fix. No local workaround.
- **Corrupted GameGuard files**: Rename `GameGuard.des` → `GameGuard.des.disabled/` directory first (preserves file for Steam re-download). Delete only if `.disabled` approach doesn't work.
- **Missing firewall ports**: Run gameguard-prepare-network.sh or manually add iptables rules for ports 28910:28919.
- **ptrace_scope too high**: Set `kernel.yama.ptrace_scope=0` in 99-gameguard.conf (must load after 99-security-hardening.conf).
- **nProtect auth hang**: Create `GameGuard.des.disabled/` directory in game's `DATA/Win64/` path. Comment out `api.gameguard.net` and `update.gameguard.net` in `/etc/hosts` as backup.

### Steam Log Patterns
- Game launches, all sub-processes exit with code -1 within seconds → anti-cheat handshake failed
- `GameGuard: authentication failed` → DNS or auth server issue
- `Unable to query trim descriptor on volume` → benign GameGuard artifact, ignore

## EAC / BattlEye
- Similar handshake pattern to GameGuard
- EAC: check `EasyAntiCheat` folder in game directory
- BattlEye: check `BattlEye` folder, `BeClient.dll`
- Both: ptrace_scope must be 0 or 1 for anti-cheat to function
- Both: may require dedicated server access for some features