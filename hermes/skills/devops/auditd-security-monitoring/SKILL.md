<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
title: Auditd Security Monitoring
name: auditd-security-monitoring
description: Linux auditd for security monitoring and attack detection.
---

## Use when:
Enabling system-level attack detection and logging for Linux environments.

## Behavior:
Set up and configure the Linux Audit Framework (auditd) for security monitoring, create detection scripts, and manage audit rules for detecting unauthorized access, privilege escalation, and system tampering.

## Key Capabilities

### 1. Install & Enable auditd
```bash
# Check if installed
which auditctl && systemctl status auditd

# Enable and start
sudo systemctl enable --now auditd
```

### 2. Load Audit Rules
Create rules file at `~/.config/audit/rules.d/security.rules`:
```bash
# Define rules for critical security events
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_change
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /home/$USER/Projects -p wa -k project_tamper
-w /home/$USER/.gnupg -p wa -k gpg_access
```

### 3. Verify Rules Loaded
```bash
sudo auditctl -l  # List loaded rules
sudo auditctl -D  # Clear all rules
sudo auditctl -R /path/to/rules  # Load from file
```

## Attack Detection Script
Place at `/bin/attack-monitor.py` for scheduled checks:
- Checks audit logs for suspicious events
- Monitors for SSH brute force
- Detects privilege escalation attempts
- Logs to `/security-logs/attacks.json`

## Common Attack Patterns to Monitor (SUSPICIOUS_PATTERNS)
- SSH brute force: 'Failed password', 'Invalid user'
- Privilege escalation: 'uid!=euid', 'sudo:'
- File tampering: 'passwd_changes', 'shadow_changes'
- Crypto access: 'faucet_access', 'crypto_access'

## Log Locations
- `/var/log/audit/audit.log` - Main audit stream
- `/var/log/auth.log` or `journalctl -u sshd` - SSH events
- Custom: `/home/$USER/security-logs/`

## Pitfalls & Fixes

1. **Rules file exists but rules are NOT loaded**
   Having a rules file (`audit.rules`) does NOT mean rules are active. Always verify after loading:
   ```bash
   sudo auditctl -R /path/to/rules && sudo auditctl -l
   # If -l shows "No rules" after a -R attempt, the load FAILED silently.
   # On this system, the most common cause is readonly root from a btrfs
   # snapshot (see pitfall #5) — auditctl appears to succeed but the kernel
   # rejects the rule writes. Check `mount | grep "on / "` BEFORE troubleshooting
   # the rules file. Reload with `sudo auditctl -D && sudo auditctl -R /path/to/rules`
   # and re-check: if still empty, you are on a readonly snapshot.

2. **`/var/log/auth.log` may not exist**
   On systemd/Arch-based systems (Garuda, Arch), `auth.log` is often absent — SSH and PAM events live in the journal only. Do not treat a missing `auth.log` as "no auth activity"; check `journalctl -u sshd` and `journalctl _SYSTEMD_UNIT=pam.unix` instead. If SSH daemon is disabled/inactive, there is no SSH exposure to assess. Also check whether `sshd` is enabled: `systemctl is-enabled sshd` — disabled+inactive means no SSH attack surface.

3. **Attack monitor flags LOCAL processes, not just external attacks**
   The monitor flags processes matching "miner", "stratum", "botnet" patterns. These are often self-run mining rigs (`/home/sin/miners/`) — local, user-launched processes, not intrusions. The same false-positive pattern applies to localhost listeners: crypto-bot node (4123), kdeconnectd (1716), SRBMiner API (21550) are all intentional local services. Triage every alert against `ps` / `ss` / the process binary path before treating it as an attack. An alert is a lead, not a conclusion. Check: `ps aux | grep <flagged-name>`, `ss -tunapl | grep <port>`, and the binary's real path (`ls -l /proc/<pid>/exe`) to determine if it's self-owned. See `devops/arch-system-hardening/references/network-listeners.md` for the full localhost service table and risk levels.

4. **Martian source packets are often benign**
   `IPv4: martian source` from the system's own DNS server (e.g. 10.128.128.128) is frequently a routing/NAT artifact, not spoofed attack traffic. Check whether the source IP is a known local service (DNS, DHCP) before raising an alert. Firewall drop logs for such traffic show the guard is working, not that an attack is in progress. To triage: `nmcli device show | grep -i dns` to see if the source is your configured DNS; `ip neigh` to check if the MAC is your gateway; `sysctl net.ipv4.conf.*.log_martians` and `rp_filter` to see kernel settings; `dmesg` to check if the martian messages are from the current boot or old boots.

5. **Readonly root prevents rule loading and log writes**
   If `auditctl -R` silently fails, `systemctl` operations error with `Read-only file system`, and `/boot` or `/var/lib` won't accept writes, the system may be booted into a readonly BTRFS snapshot rather than the live root subvolume. Diagnose before assuming the tools are broken:
   ```bash
   mount | grep "on / "          # look for subvol=@/.snapshots/<N>/snapshot (readonly)
   btrfs subvolume show /        # shows current subvolume and whether it has the readonly flag
   sudo btrfs subvolume set-default <@-subvolid> /   # restore default to live @ subvolume
   ```
   After changing the default, a reboot is required — the current session stays readonly. `grub.cfg` in the snapshot subvolume will be stale; the live `@` subvolume's `/boot/grub/grub.cfg` is the working one. The `grub-btrfs` plugin auto-generates snapshot boot entries into `grub-btrfs.cfg` so the GRUB menu can boot any snapshot; when booted into a snapshot, that snapshot's grub.cfg is what GRUB loaded, and regenerating it requires writing to the snapshot (impossible while readonly).

   **Watch for secondary symptoms:** `plocate.timer` failures (`fchmod() of /var/lib/plocate/plocate.db failed: Read-only file system`), `systemd-backlight` write failures, `systemd-random-seed` failures, and `pacman -Syu` rejecting transactions with "Rejecting pacman transaction if running in snapshot" all indicate the same readonly-root trap. Check `mount | grep "on / "` before troubleshooting any of these individually.

6. **Rules not persisting after reboot**
   Solution: Ensure `/etc/audit/audit.rules` exists and contains all rules. Run:
   ```bash
   sudo auditctl -l > /etc/audit/audit.rules
   ```

7. **Permission denied errors**
   - auditd needs root to modify kernel parameters
   - Use sudo for auditctl commands
   - Rules in `/etc/` need root to modify

8. **audit.log grows too large**
   Add rate limiting to rules: `-F success=0` for failed attempts only

10. **auditd shows active but zero rules loaded** — common after snapshot boot or failed `auditctl -R`. Always verify with `sudo auditctl -l` after any rules load attempt. If empty, check for readonly root (pitfall #5) before assuming the load succeeded.

## Zen Suite vulkan-shader-cache Pipeline

The `zen-vulkan-shader-cache.service` pre-warms Vulkan shader pipelines at boot:
- Service unit: `/etc/systemd/system/zen-vulkan-shader-cache.service` (runs as `zen` user)
- JS module: `/opt/zen-core/modules/vulkan-shader-cache.js` (standalone build, no external imports)
- Permutations JSON: `/opt/zen-core/modules/sample-shader-permutations.json` — must use `"variants"` key (not `"permutations"`), each entry with `shader`, `entrypoint`, `stage`
- Cache dir: `/var/cache/zen/shader-cache/` (zen:zen, 700)
- Install script: `zen-core/modules/install-vulkan-shader-cache.sh`

**Path mismatch trap**: the install script copies `.ts` → `.js` but the compiled JS hardcodes the source path (`/home/sin/zen-suite/` vs actual `/home/sin/zen/linux-zen-suite/`). After install, verify with `journalctl -u zen-vulkan-shader-cache -n 5` — "Loaded 0 shader variants" means path mismatch or wrong JSON shape.

**zen user traversal**: parent directories must have +x for non-owners, or the zen user cannot reach the permutations file even if the file itself is 644. Check with `sudo -u zen stat <path>`.

## Arch/Garuda System Audit Quick Checks

Run these at the start of any hardening session:

```bash
# Disk space
df -h / && du -x / -xdev --max-depth=1 -h 2>/dev/null | sort -rh | head -10

# Orphaned packages
pacman -Qdtq

# Pending updates
checkupdates

# Failed services
systemctl list-units --failed --no-pager

# Error log scan
journalctl -p warning --since "6 hours ago" --no-pager -q | grep -v 'powerdevil\|plasmashell\|kwin\|udev-worker'

# Listening ports
ss -tlnp

# Hermes config check
grep 'default:' /home/sin/.hermes/config.yaml | head -2
```

## Example Cron/Scheduled Check
```cron
*/5 * * * * /usr/bin/python3 /home/$USER/bin/attack-monitor.py
```

Or create systemd timer at:
- `/etc/systemd/system/attack-monitor.service`
- `/etc/systemd/system/attack-monitor.timer`
