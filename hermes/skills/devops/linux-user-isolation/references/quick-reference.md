# linux-user-isolation Quick Reference

## Session-Specific Details (Garuda Linux / Arch)

### Users
- Main user: `sin` (uid=1000, gid=1000)
- Isolation user: `ai` (uid=949, gid=949) — created with `useradd -r -s /usr/sbin/nologin -M ai`
- `ai` has no login shell, no home directory auto-creation

### Key Paths
- Hermes launcher: `/usr/local/bin/hermes-launcher` (not yet created — blocked pending user consent)
- OpenCode launcher: `/usr/local/bin/opencode-launcher` (not yet created)
- Hermes venv Python: `/home/sin/.hermes/hermes-agent/venv/bin/python`
- Hermes CLI script: `/home/sin/.hermes/hermes-agent/hermes`
- OpenCode binary: `/usr/bin/opencode`
- Hermes wrapper shim: `/home/sin/.local/bin/hermes` (bash wrapper, root-owned, small)
- Hermes config/data: `/home/sin/.hermes/` (copied to `/home/ai/.hermes/`)

### Firewall State Before Block
- nftables: table `inet firewalld` active, owned by firewalld
- iptables: empty filter rules; firewalld uses nft backend
- AppArmor: **not installed** (`apparmor_parser` absent)
- Netfilter modules loaded: nf_conntrack, nft_*, xt_*

### Services Running as `sin` That Would Be Blocked
- Hermes Agent (gateway + kernel runners)
- OpenCode (not currently running)
- Waydroid (running; has its own virtual interface `waydroid0`)
- minerd (pid 1144, connecting to 166.117.191.140:3333)
- Firedragon browser (PID 2645)

### UID-Based Rule Target

```bash
# Block sin (uid=1000), allow ai (uid=949), allow loopback
sudo nft add table inet block_sin
sudo nft add chain inet block_sin output { type filter hook output priority -10; policy accept; }
sudo nft add rule inet block_sin output uid 1000 drop
sudo nft add rule inet block_sin output uid 949 accept
sudo nft add rule inet block_sin output oif lo accept
```

### Reversal

```bash
sudo nft delete table inet block_sin
# If iptables-nft layer was used:
sudo iptables-nft -F OUTPUT
```
