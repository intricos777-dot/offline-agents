<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: linux-user-isolation
description: Run tools as a dedicated Linux user for egress control.
---

# Linux User Isolation

## Trigger

Run selected tools under a dedicated system user so the main user's outbound traffic can be restricted independently.

## Core Pattern (Arch / Garuda / systemd-based)

1. **Create the isolation user:**
   ```bash
   sudo useradd -r -s /usr/sbin/nologin -M <iso_user>
   sudo mkdir -p /home/<iso_user>/.config
   sudo chown -R <iso_user>:<iso_user> /home/<iso_user>
   sudo chmod 700 /home/<iso_user>
   ```

2. **Copy required runtime state:**
   ```bash
   sudo rsync -a /home/<main_user>/.hermes/ /home/<iso_user>/.hermes/
   sudo chown -R <iso_user>:<iso_user> /home/<iso_user>/.hermes
   ```
   Also chown the tool's own installation files so `<iso_user>` can execute them.

3. **Create a setuid-root wrapper (optional):**
   ```bash
   sudo tee /usr/local/bin/<tool>-launcher << 'EOF'
   #!/bin/bash
   exec sudo -u <iso_user> <real_binary_path> "$@"
   EOF
   sudo chown root:<iso_user> /usr/local/bin/<tool>-launcher
   sudo chmod 4750 /usr/local/bin/<tool>-launcher
   ```

4. **Block the main user's outbound traffic:**

   **nftables (preferred on Arch/Garuda):**
   ```bash
   sudo nft add table inet block_<main_user>
   sudo nft add chain inet block_<main_user> output { type filter hook output priority -10; policy accept; }
   sudo nft add rule inet block_<main_user> output uid <main_uid> drop
   sudo nft add rule inet block_<main_user> output oif lo accept
   sudo nft add rule inet block_<main_user> output uid <iso_uid> accept
   ```

   **iptables-nft compatibility layer:**
   ```bash
   sudo iptables-nft -A OUTPUT -m owner --uid-owner <main_uid> -j DROP
   sudo iptables-nft -A OUTPUT -m owner --uid-owner <iso_uid> -j ACCEPT
   sudo iptables-nft -A OUTPUT -o lo -j ACCEPT
   ```

5. **nft priority matters:** place the UID-block chain at `priority -10` so it evaluates before firewalld's dispatch chains.

## Waydroid caveat

When blocking the main user's outbound, Waydroid (running as the main UID) loses its virtual `waydroid0` networking. Either migrate Waydroid to the isolation user, or add explicit nft exemptions for the main UID's Waydroid traffic before applying the block:

```bash
# Exempt Waydroid virtual interface for the main UID
sudo nft add rule inet block_<main_user> output uid <main_uid> iifname waydroid0 accept
sudo nft add rule inet block_<main_user> output uid <main_uid> oifname waydroid0 accept
```

Verify Waydroid still gets an IP after the block: `waydroid status` should show an IP, not UNKNOWN. If it goes UNKNOWN, the DHCP traffic on `waydroid0` is being dropped — add UDP/67,68 exemptions for that interface.

## UID discovery

```bash
id -u <main_user>
id -u <iso_user>
```

## Pitfalls

- **All user processes share one UID.** Every browser, terminal, GUI app, and user service on a single-user desktop runs as the main UID. Plan exemptions or migration for VPN, Waydroid, browsers, etc.
- **Waydroid defaults to the main user.** Blocking the main user's outbound will cut Waydroid networking unless it is migrated or explicitly exempted.
- **Setuid wrappers are a security boundary.** Mode `4750`, owner `root:<iso_user>`. Do not make them world-executable.
- **firewalld and custom nftables can coexist.** firewalld owns `inet firewalld`. Use a separate table (`inet block_<main_user>`) with its own hook so firewalld reloads do not destroy your rules.
- **Hermes and OpenCode inherit the shell user's UID.** UID filtering at the kernel is the only reliable way to catch their network access regardless of which binary launches them.
- **AppArmor is often absent on Arch.** Do not rely on userspace profile enforcement unless `apparmor_parser` is installed. Prefer nftables for a guarantee on vanilla Arch.
- **Copy, don't symlink, config directories across users.** Use `rsync -a` then chown; cross-user symlinks fail permission checks.

## Verification

```bash
# Isolation user can reach the network
sudo -u <iso_user> curl -I https://example.com

# Main user cannot
curl -I https://example.com
# expected: timeout / connection refused

# Loopback still works
curl -I http://127.0.0.1:9040

# Inspect active connections by UID
ss -tunp | grep -E "users:.*\(\"<main_user>\"|<iso_user>"
```

## Reversal

```bash
sudo nft delete table inet block_<main_user>
# or, for iptables-nft layer:
sudo iptables-nft -F OUTPUT
```
Remove wrappers from `/usr/local/bin/` and restore ownership of copied configs if desired.

## References

- `references/quick-reference.md` — session-specific path mapping, UIDs, current firewall state, and ready-to-apply rule snippets for Garuda Linux.
