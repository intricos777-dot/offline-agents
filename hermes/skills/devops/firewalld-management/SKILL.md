<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: firewalld-management
description: Configure firewalld zones, fix blocked network access.
tags: [firewall, networking, diagnosis, arch, garuda]
related_skills: [btrfs-snapshot-restore, linux-user-isolation]
---

# Firewalld Zone Management

## Trigger
Firewall blocks network connectivity after system updates, package removals, or anonymity framework activation.

## Diagnosing Blocking Rules

### Identify the active zone
```bash
firewall-cmd --get-active-zones
firewall-cmd --get-default-zone
```

### Check zone configuration
```bash
firewall-cmd --list-all
```

### Examine XML zone file
```bash
cat /etc/firewalld/zones/<zone>.xml
```

## Common Problem Patterns

### Zone target="DROP" blocks all traffic
The `target` attribute defines what happens to packets not explicitly allowed. `DROP` silently discards them.

**Fix:** Change to `target="ACCEPT"` or `target="default"`

### Rich rules blocking specific traffic
XML zone files may contain restrictive rich rules blocking ports or MAC addresses.

**Symptom:** WiFi works but specific services fail
**Fix:** Remove restrictive `<rule>` elements

### Port blocks breaking discovery
| Port | Protocol | Service | Impact |
|------|----------|---------|--------|
| 5353 | UDP | mDNS | Network discovery fails |
| 1900 | UDP | SSDP | Device detection fails |
| 1716 | TCP/UDP | KDE Connect | File sharing fails |

## Safe Zone Modification

### Direct XML edit (persistent)
```xml
<zone target="ACCEPT">
  <service name="dhcpv6-client"/>
  <forward"/>
</zone>
```

### firewall-cmd (immediate)
```bash
# Remove restrictive rules
sudo firewall-cmd --permanent --remove-port=5353/udp
sudo firewall-cmd --permanent --remove-port=1716/tcp
sudo firewall-cmd --permanent --change-zone=enp0s20f0u4 public

# Reload
sudo firewall-cmd --reload
```

## Snapshot-Based Systems

On Garuda with btrfs snapshots, configs may be read-only if snapshot is marked `ro=true`.

**Check:** `btrfs property get -ts /`

**Temporarily enable writes:** `sudo btrfs property set -ts / ro=false`

### Creating a new writable snapshot
```bash
sudo btrfs subvolume snapshot -r / /.snapshots/new-state
sudo btrfs property set -ts /.snapshots/new-state ro=false
```

## Pitfall: firewalld target="DROP" with masquerade
A DROP target combined with masquerade causes asymmetric routing: outgoing packets get NAT but return traffic is dropped. Always use ACCEPT or default target for desktop systems.