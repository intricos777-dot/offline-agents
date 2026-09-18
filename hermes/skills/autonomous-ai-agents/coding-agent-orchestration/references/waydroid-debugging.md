# Waydroid / LXC Session Debugging Notes

## Verified layout
- `waydroid status` reflects **session** state only; it can stay `STOPPED` even when `waydroid-container.service` is active/running.
- Container lifecycle is separate: `waydroid container start|stop|restart`.
- Session lifecycle is separate: `waydroid session start|stop`.
- Container can show `FROZEN`; use `waydroid container unfreeze` before checking state.

## Common no-input-path failures
- `org.freedesktop.DBus.Error.NotSupported: Using X11 for dbus-daemon autolaunch was disabled at compile time` => set `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` and `XDG_RUNTIME_DIR=/run/user/1000`.
- `lxc-start: ... turn_into_dependent_mounts: 3356 No such file or directory` is often benign; container may still reach `RUNNING`.
- `lxc.hook.post-stop` exit 126 during stop is usually a scripts/permissions issue, not the root cause of a stopped session.

## Hard dependency checks
- Kernel: classic `CONFIG_ANDROID_BINDER_IPC=y` was the historical requirement. On modern Arch kernels (≥6.18, including linux-zen 7.2.2 and linux-lts 6.18.x), only `CONFIG_ANDROID_BINDER_IPC_RUST=y` is available. This introduces a known regression: large binder transactions can fail with `ENOSPC`, crashing Waydroid. There is no runtime sysctl/boot-param workaround.
- `ashmem` is preferred but some setups can run with only binderfs.
- Verify `lxc-checkconfig` before troubleshooting higher layers.
- For cgroup readonly errors from Android `libprocessgroup`: this usually means the container cgroup mount is read-only. On LXC 7.0.0, `cgroup:delegate` may be rejected as an invalid automount target; do not assume that syntax works on every LXC version.

## Firewall / network
- `waydroid status` shows `IP address: UNKNOWN` when the dnsmasq lease file is empty.
- On firewalld-managed hosts, `DEVICE-GUARD` nft chain can drop DHCP broadcasts on `waydroid0` before dnsmasq sees them. Adding interface `waydroid0` to the `trusted` zone may help, but inspect `nft list ruleset` to verify `DEVICE-GUARD` evaluation order.
- Manually seeding the dnsmasq lease file is a temporary workaround but does not fix the firewall path.

## Packaging / image bugs
- `waydroid-image-gapps` and VANILLA images may share the same `vendor.img`; reinitializing with `--system_type GAPPS` will **not** fix missing vendor HAL binaries.
- Missing HAL binaries in `vendor.img` are upstream packaging bugs; document and report, do not silently reinitialize.

## Log priority
- `sudo journalctl -u waydroid-container --no-pager -n N` for service-side events.
- `sudo waydroid --details-to-stdout logcat` for container-side logs.
- `sudo lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH` for raw container state.
- `sudo dmesg --level=err,warn | grep -E 'rust_binder|createProcessGroup|DEVICE-GUARD-BLOCK'` for kernel-side regressions.
