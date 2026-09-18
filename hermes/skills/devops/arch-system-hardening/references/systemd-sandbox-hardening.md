# Systemd Sandbox Hardening Patterns

When wrapping local services (especially those that bind ports or expose APIs), apply these directives from the systemd unit file:

```ini
[Service]
Type=simple
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/zen /var/cache/zen
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=true
KillMode=mixed
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
CapabilityBoundingSet=
AmbientCapabilities=
```

Key principles:
- `NoNewPrivileges=true` — prevents gaining new privileges via setuid
- `ProtectSystem=strict` — makes everything read-only except `/dev`, `/proc`, `/sys`
- `ReadWritePaths` — explicitly grant write access to ONLY the dirs the service needs
- `ProtectHome=true` — hides `/home`, `/root`, `/run/user`
- `PrivateTmp=true` — private /tmp + /var/tmp namespace
- `PrivateDevices=true` — no access to physical devices
- `ProtectKernelTunables=true` — hides `/proc/sys` and `/sys`
- `ProtectKernelModules=true` — can't load/unload kernel modules
- `ProtectKernelLogs=true` — no access to kernel log (prevents log reading)
- `ProtectControlGroups=true` — read-only cgroup hierarchy
- `RestrictAddressFamilies` — only allow specific socket families
- `CapabilityBoundingSet=` (empty) — drops ALL Linux capabilities
- `AmbientCapabilities=` (empty) — no ambient capabilities granted
- `RestrictSUIDSGID=true` — blocks setuid/setgid binaries
- `RestrictNamespaces=true` — can't create new namespaces
- `KillMode=mixed` — kill all remaining processes on stop

This pattern is applied to:
- `zen-ai-coordination.service` (MCP gateway on 127.0.0.1:4141)
- `zen-intrusion-notify.service` (libnotify + syslog watcher)
- `zen-vulkan-shader-cache.service` (pipeline cache daemon)

For services that need networking: add `AF_INET AF_INET6` to `RestrictAddressFamilies`.
For services that need to bind ports < 1024: add `cap_net_bind_service` to `CapabilityBoundingSet`.
