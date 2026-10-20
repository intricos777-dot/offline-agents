<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
# Arch System Audit Checklist

One-shot checklist for cron or manual runs, including localhost pentest sweep.

## Quick Scan (30s)

```bash
# System state
uname -r; df -h /; pacman -Qdtq; checkupdates 2>/dev/null | wc -l
systemctl list-units --failed --no-pager; ss -tlnp
grep 'default:' /home/sin/.hermes/config.yaml

# Localhost recon — what's listening and who owns it?
sudo ss -tulpn | grep LISTEN
find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l
getcap -r / 2>/dev/null | grep -v snapshots | wc -l
```

## Deep Scan (5min)

### External exposure

```bash
# All 1000 top ports should be filtered/dropped
sudo nmap -sS -sV --top-ports 1000 -T4 127.0.0.1 -oN /tmp/nmap-localhost.txt
sudo nmap -sS -sV --top-ports 1000 -T4 10.145.133.214 -oN /tmp/nmap-wifi.txt
# Expect: external ports all "filtered", localhost has only known services

# Service fingerprinting on localhost listeners
sudo nmap -sS -sV -p 4123,9050,9040,21550,1716 -T4 127.0.0.1
```

### Local service identification

For each open localhost port, trace to its process:

```bash
# Get PID for each listener
sudo ss -tlnp | grep LISTEN

# For suspicious ports (e.g. 4123, 21550), get full process context:
PID=1827  # replace with actual PID
ps -p $PID -o pid,user,comm,args
readlink /proc/$PID/exe
cat /proc/$PID/cmdline | tr '\0' ' '
```

### Log scan

```bash
journalctl -p warning --since "1 day ago" --no-pager -q 2>/dev/null | grep -v 'powerdevil\|plasmashell\|kwin\|udev-worker' | head -30
pacman -Qk 2>/dev/null | grep 'missing files'
snapper list 2>/dev/null | tail -5
cat /etc/NetworkManager/conf.d/99-privacy.conf 2>/dev/null
grep 'default:' /home/sin/.hermes/config.yaml
```

### Auditd verification

```bash
# Rules file existing does NOT mean rules are loaded
sudo auditctl -l  # must list rules; "No rules" = NOT active
[ ! -s "$(sudo auditctl -l)" ] && echo "AUDIT RULES NOT LOADED"
```

## Risk triage

| Port | Service | Risk | Action if unexpected |
|------|---------|------|---------------------|
| 9050 | tor SOCKS | low | Expected — intentional Tor usage |
| 9040 | tor TransPort | low | Expected — intentional Tor usage |
| 5353 | tor DNSPort | low | Expected — Tor DNS |
| 53 | dnscrypt-proxy | low | Expected — DNS resolver |
| 4123 | node (crypto-bot) | check | Verify auth; consider 127.0.0.2 binding |
| 21550 | SRBMiner API | medium | Bind to 127.0.0.1, firewall, or disable --api-enable |
| 1716 | kdeconnectd | low-med | Disable LAN backend if unused |
| 5353 | avahi (mDNS) | low | Standard zeroconf |

## Post-Fix Verification

```bash
systemctl status tor.service dnscrypt-proxy.service --no-pager | grep Active
pacman -Qdtq
du -x / -xdev --max-depth=1 -h 2>/dev/null | sort -rh | head -5
sudo auditctl -l | head -10
```
