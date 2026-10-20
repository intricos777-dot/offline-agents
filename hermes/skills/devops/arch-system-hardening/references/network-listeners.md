<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
# Network Listener Patterns

Expected listeners on this Garuda system:

|| Port | Proto | Service | Bind | Status |
||------|-------|---------|------|--------|
|| 9050 | TCP | tor SOCKS | 127.0.0.1 | active |
|| 9040 | TCP | tor TransPort | 127.0.0.1 | active |
|| 5353 | UDP | tor DNSPort | 127.0.0.1 | active |
|| 53 | TCP+UDP | dnscrypt-proxy | 127.0.2.1 | active |
|| 4123 | TCP | node TSX (crypto-bot) | 127.0.0.1 | active |
||| 21550 | TCP | SRBMiner API | 127.0.0.1 | **was `0.0.0.0`, now loopback — see 2h** ||
||| 1716 | TCP+UDP | kdeconnectd | 0.0.0.0 | intentional, 0 paired devices |
|| 5353 | UDP | avahi (mDNS) | * | intentional |

Unexpected (investigate):
- Any listener on `0.0.0.0` not in the table above
- Any listener NOT in the table above (new service = potential exposure)
- Port 21550 (SRBMiner API) is bound to 0.0.0.0 — add `--api-ip 127.0.0.1` or equivalent to bind loopback only

## Localhost service triage

When a port is open on 127.0.0.1, determine what it is before assessing risk:

```bash
# Identify the PID owning the listener
sudo ss -tlnp | grep :<port>

# Get the process details
ps -p <PID> -o pid,user,comm,args
readlink /proc/<PID>/exe
cat /proc/<PID>/cmdline | tr '\0' ' '

# Verify what it is — is it a known tool or an anomaly?
```

### Known localhost services

| Port | Process | Risk | Notes |
|------|---------|------|-------|
| 9050 | tor | low | Client SOCKS proxy, no auth. Intentional Tor usage. |
| 9040 | tor | low | Transparent proxy. Intentional Tor usage. |
| 5353 | tor/avahi | low | DNSPort (Tor) or mDNS (avahi). Both intentional. |
| 53 | dnscrypt-proxy | low | DNS only, no HTTP API. |
| 4123 | node TSX | **hardened** | crypto-bot API. Requires `Authorization: Bearer <BOT_API_KEY>` on all POST routes, rate-limited (30 req/min global, 5/min on /exec). Source patched in `src/server/api.ts` — added `express-rate-limit` dependency, bearer-token middleware, `requireAuth` on `/exec`, `/trade`, `/sweep`, `/skill`, `/agent-message`. Verify: `curl -s http://127.0.0.1:4123/exec -X POST -d '{"command":"id"}'` returns 401/503, not command output. |
| 1716 | kdeconnectd | low-med | 0 paired devices = low risk. Can disable LAN backend. |
| 21550 | SRBMiner | **low** | API now bound to 127.0.0.1 via `--api-bind 127.0.0.1` in mine-gpu-btc.sh. Was 0.0.0.0, no auth. ||

### External exposure verdict

- **All non-whitelisted inbound traffic: DROP** (firewalld nftables + device-guard iptables chain)
- nmap `-sS -p 1000 -sV` against WiFi IP shows all ports filtered
- Localhost services are only reachable by local processes (uid=1000 or root)
- The exception is port 21550 (0.0.0.0) — firewalled but should be bound to loopback

## Pitfalls

- **Readonly root** — All writes fail; check `mount | grep "on / "` before troubleshooting
- **dirmngr socket conflicts** — Kill dirmngr, remove stale files from `/etc/pacman.d/gnupg/`
- **NM privacy.conf key** — Use `mac-address-seeded` not `new-cloned-mac-address`
- **AUR packages** — Review before removing; cpuminer/hermes-pm/zen-suite may be intentional
- **Model mismatch** — hermes config may lag provider switch; verify with `grep default`
- **Rate limit errors** — Old model errors linger in logs after switch; check `grep -c 'RateLimitError' /home/livings/.hermes/logs/errors.log`
- **nmap requires root** for `-sU` (UDP) and `-sS` (SYN scan) — use `sudo -n nmap` for full-spectrum localhost scans
- **Port 21550 bound to 0.0.0.0 is a false-negative risk** — firewalld blocks it externally, but if firewalld restarts in a degraded state, SRBMiner API is internet-exposed. Bind to `127.0.0.1` or use `--api-bind 127.0.0.1`.
- **Local API `/exec` endpoints leak env to child processes** — `child_process.exec` with `env: { ...process.env }` passes ALL environment variables (including secrets, tokens, HOME paths) to the spawned shell. Always filter to a minimal env: `env: { PATH: '/usr/local/bin:/usr/bin:/bin', HOME: process.env.HOME || '/tmp' }`.
- **Regex blocklists on command exec are bypassable** — patterns like `/rm -rf \//`, `/mkfs/`, `/dd if=/` can be defeated via encoding (`\\x72\\x6d`), symlinks, or alternate binaries (`busybox rm`, `find / -delete`). Auth + rate limiting + loopback binding are the real controls; the blocklist is merely defense in depth.