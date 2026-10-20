<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: arch-system-hardening
description: "Full system audit, hardening, and patching on Arch/Garuda."
tags: [arch, garuda, hardening, audit, pacman, btrfs]
---

# Arch System Hardening

## Trigger

Run a full system audit and harden on Arch/Garuda after restore, major updates, or when the user says "audit", "harden", "patch everything".

## Phase 1 — Gather State (parallel)

Run all diagnostics in parallel, plus a localhost pentest sweep:

```bash
# System state (single command, parallel)
uname -a; df -h /; btrfs subvolume list / 2>/dev/null | tail -5
pacman -Qk 2>/dev/null | grep -v ': 0 missing' | head -5; pacman -Qdtq; checkupdates 2>/dev/null
systemctl list-units --failed --no-pager; journalctl -p err --since "1 hour ago" --no-pager -q 2>/dev/null | grep -v 'powerdevil\|plasmashell\|kwin\|udev-worker' | head -20
ss -tlnp
grep 'default:' /home/sin/.hermes/config.yaml | head -2
ls -lat /home/sin/.hermes/logs/ | head -5; du -x /home/sin/.hermes/logs/ -sh

# Localhost pentest sweep — identify ALL listeners and their owners
sudo ss -tulpn; echo "=== SUID ==="; find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | sort; echo "=== CAPS ==="; getcap -r / 2>/dev/null | grep -v snapshots; echo "=== nmap localhost ==="; sudo nmap -sS -sU --top-ports 1000 -T4 127.0.0.1 -oN /tmp/nmap-localhost.txt
```

## Phase 2 — Remediation (in order)

### 2a. Remove orphaned packages (free space, reduce attack surface)
```bash
pacman -Qdtq  # review first — do NOT blindly remove
sudo pacman -Rns $(pacman -Qdtq) --noconfirm
```
**Pitfall**: blind orphan removal can pull in dependencies you want (e.g., `cpuminer`, `zen-suite` are AUR foreign packages — `pacman -Qmq` separates them from official orphans). Always inspect `pacman -Qdtq` output before running the remove.

### 2b. Clean package cache
```bash
sudo pacman -Sc --noconfirm
sudo rm -rf /var/cache/pacman/pkg/download-* 2>/dev/null
paccache -rk3 2>/dev/null
```

### 2c. Fix read-only root (common after btrfs snapshot restore)
If `systemctl` writes fail or `pacman -Syu` says "Rejecting pacman transaction if running in snapshot":
```bash
mount | grep "on / "                          # check subvol
sudo btrfs subvolume set-default <@-subvolid> /
# Reboot required — current session stays readonly
```

### 2d. Enable disabled services
```bash
sudo systemctl enable --now tor.service
sudo systemctl enable --now dnscrypt-proxy.service
```

### 2e. Fix known config errors
- **NM privacy.conf**: `new-cloned-mac-address` key is invalid; replace with `mac-address-seeded`
- **Hermes model**: update `default:` in `/home/sin/.hermes/config.yaml` to match the active provider/model
- **plocate timer failing**: `/var/lib/plocate` owned by root → read-only for user; fix: `sudo chown -R sin:sin /var/lib/plocate/ && sudo chmod 755 /var/lib/plocate/ && sudo updatedb` — timer recovers after fix
- **hermes-pm AUR package**: user-requested removal; `pacman -Ql hermes-pm` shows it owns `/usr/bin/hermes` — confirm before removing as it may conflict with the hermes-agent venv binary

### 2f. Clear stale sockets and caches
```bash
sudo pkill -9 dirmngr 2>/dev/null
rm -f /etc/pacman.d/gnupg/S.dirmngr /etc/pacman.d/gnupg/S.gpg-agent.* 2>/dev/null
rm -rf /home/sin/.cache/ 2>/dev/null
```

### 2f1. Remove hermes-pm (AUR) if user requests
`hermes-pm` owns `/usr/bin/hermes` — conflicts with venv binary at `/home/sin/.hermes/hermes-agent/venv/bin/python /home/sin/.hermes/hermes-agent/hermes`.
Check with `pacman -Ql hermes-pm` before removing. Remove: `sudo pacman -Rns hermes-pm --noconfirm`

### 2h. Auditd rule loading
```bash
# Load rules — MUST use realpath; relative/symlink paths trigger "nested rule files not supported"
sudo auditctl -R "$(realpath /home/sin/security-audit-2026/logs/security-logs/audit.rules)"
# Verify:
sudo auditctl -l  # should show all rules, not empty
sudo auditctl -s  # enabled 1 = active
```

**Pitfall**: `auditctl -R /relative/path/to/rules` fails silently with `"nested rule files not supported"` if the path contains symlinks or `../` segments. Always resolve with `realpath` first. After loading, verify with `auditctl -l` — if empty, the rules did NOT load.

After the pentest sweep identifies localhost services, verify local APIs have authentication. The pattern:

1. **Identify the listener**: `sudo ss -tlnp | grep :<port>` → get PID → `ps -p <PID> -o args` → `readlink /proc/<PID>/exe` → `cat /proc/<PID>/cmdline | tr '\0' ' '`
2. **Read the source** to find auth checks or blocklist validation
3. **If no auth**: add `Authorization: Bearer <key>` middleware with `req.headers.authorization` check; reject all mutating routes (`/exec`, `/trade`, `/sweep`) with 401 if key missing or mismatched
4. **Defense in depth**: even if the API is read-only, bind it to `127.0.0.2` instead of `127.0.0.1` so only processes explicitly targeting that address can reach it
5. **Rate limiting**: add `express-rate-limit` (30 req/min global, 5/min on exec) to prevent brute-forcing even with a key set
6. **Restart** the service and re-verify the listener
7. **Verify the fix**: `curl -s http://127.0.0.1:<port>/exec -X POST -d '{"command":"id"}'` must return 401/503, not command output

**The crypto-bot pattern** (apply to any similar local API):

- `/exec` endpoint passes user-controlled strings to `child_process.exec` with a regex blocklist — blocklists are bypassable via encoding (`\\x72\\x6d`), symlinks, or alternate binaries (`busybox rm`, `find / -delete`). Replace with: require API key + rate limit + bind to `127.0.0.2`. If exec is not needed, remove the endpoint entirely.
- `child_process.exec` with `env: { ...process.env }` leaks ALL environment variables to the spawned shell. Filter to minimal: `env: { PATH: '/usr/local/bin:/usr/bin:/bin', HOME: process.env.HOME || '/tmp' }`.
- Always verify the fix works by curling the endpoint without auth and confirming it is rejected.
- The `express-rate-limit` npm package must be added to `package.json` dependencies and installed.

### 2h. Bind local daemons to loopback only
- Miner APIs (`--api-bind 127.0.0.1`), database sockets, custom tools: any `--api-enable` flag must include a `--bind` or `--ip` flag for `127.0.0.1` or `127.0.0.2`.
- Services currently on `0.0.0.0` (kdeconnectd, SRBMiner): add bind flags or firewall-cmd rich rules as a stopgap if the service can't be reconfigured.

### 2i. Vacuum journals
```bash
sudo journalctl --vacuum-size=50M --no-pager
```

## Phase 3 — Verify

```bash
systemctl status tor.service dnscrypt-proxy.service --no-pager | grep Active
ss -tlnp
df -h /
grep 'default:' /home/sin/.hermes/config.yaml
pacman -Qdtq
pacman -Qmq  # AUR review
```

## Pitfalls

- **Read-only root** — if any write fails, check `mount | grep "on / "` BEFORE troubleshooting the tool. The trap affects systemctl, pacman, auditctl, and plocate.timer. Fix: `btrfs subvolume set-default <@-subvolid> /` + reboot.
- **plocate.timer failing** — symptom of readonly /var/lib/plocate. Fix the readonly root first; the timer will recover after reboot.
- **NM privacy.conf** — the key `new-cloned-mac-address` was deprecated/renamed in newer NetworkManager; causes warnings on every reload.
- **dirmngr socket conflicts** — stale sockets in `/etc/pacman.d/gnupg/` after kills; remove and restart.
- **Hermes model mismatch** — after provider changes, the config `default:` field may still point at the old model; update it to match the active provider.
- **AUR packages** — `pacman -Qmq` shows foreign packages; review before removing. `cpuminer`, `zen-suite` may be intentional user packages — flag for review, do not remove. `hermes-pm` owns `/usr/bin/hermes` (venv binary at `/home/sin/.hermes/hermes-agent/venv/bin/python /home/sin/.hermes/hermes-agent/hermes`) — safe to remove if user requests.
- **Concurrent opencode instances** — multiple opencode PIDs may exist (one per terminal pts). Check `ps aux | grep opencode` to identify which session is which before killing or snapshotting.
- **NVIDIA out-of-tree** — `nvidia` module taints kernel; ASPM/bios issues are firmware-level, not pacman-fixable.
- **ENOSPC → app crash** — when disk is full, Electron/Node apps throw uncaught ENOSPC in main process; fix: free space (pacman cache is the usual culprit), then delete the app's config dir if it blocks clean restart.

## Post-Hardening Checklist

- [ ] Orphans removed
- [ ] Services enabled and running
- [ ] Config errors fixed
- [ ] Disk space recovered
- [ ] Listeners bound to localhost only
- [ ] Journal vacuumed
- [ ] Model config matches active provider

## Pitfalls

- **Zen AI gateway**: Ollama on port 4141 — install with `ollama.com/install.sh`, set `OLLAMA_HOST=0.0.0.0:4141`, pull a model after install
- **ISO builds**: use pacstrap+xorriso, NOT Docker (docker.sock permission denied); boot files at `/usr/lib/syslinux/bios/`
- **Waydroid GAPPS**: kill stale pacman, remove db.lck, use `--overwrite` for conflicting files; session start needs GUI/D-Bus
- **Gaming + ptrace_scope**: `yama.ptrace_scope=3` breaks GameGuard-based games (Helldivers 2 error 122, other anti-cheat titles). GameGuard uses ptrace for self-scanning and fails immediately when it can't. If the user needs to run such games:
  1. Lower to `ptrace_scope=1` (restricted, allows parent-child tracing) — enough for GameGuard's self-scan
  2. The YAMA module rejects ALL runtime writes (`sysctl -w`, `/proc/sys/kernel/yama/ptrace_scope`, `tee` all return EINVAL). The only reliable fix is the GRUB boot parameter: add `yama.ptrace_scope=1` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg`
  3. Also edit `/etc/sysctl.d/99-security-hardening.conf` (with backup to `.bak`) so it matches on next boot — though the GRUB parameter is what actually takes effect
  4. This is a standard kernel parameter used by millions of Ubuntu/Debian systems; does not break boot. If GRUB fails, the old kernel still loads from the snapshot menu
  5. Before changing ptrace_scope, ask the user — it weakens a security boundary. Document the tradeoff and let them decide

## References

- `references/read-only-root-workflow.md` — detailed btrfs snapshot/readonly root diagnosis and recovery
- `references/audit-checklist.md` — one-shot audit checklist for cron or manual runs
- `references/network-listeners.md` — expected vs unexpected listener patterns on this system
- `references/systemd-sandbox-hardening.md` — systemd unit hardening directives for local service sandboxing
- `references/bootable-iso.md` — building a bootable ISO from zen-suite with grub-mkrescue
