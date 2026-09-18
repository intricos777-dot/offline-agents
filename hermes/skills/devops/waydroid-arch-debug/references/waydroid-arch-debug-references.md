# Waydroid Arch Debug References

## missing-hal.md

**Symptom:** `init: Could not start service 'vendor.audio-hal-2-0' ... Cannot find '/vendor/bin/hw/android.hardware.audio@2.0-service'`

**Cause:** Packaging bug in upstream `lineage_waydroid_x86_64` vendor image. The `vendor.img` is missing the `@2.0-service` binary while only providing `@4.0` libraries.

**Investigation commands:**
- `sudo mkdir -p /mnt/vendor && sudo mount -o loop,ro /usr/share/waydroid-extra/images/vendor.img /mnt/vendor`
- `sudo find /mnt/vendor -path '*android.hardware.audio*'`
- `sudo ls -la /var/lib/waydroid/rootfs/vendor/bin/hw/`

**Workaround:** Symlink `android.hardware.audio@4.0-impl.so` to `android.hardware.audio@2.0-service` inside `vendor.img`. This is a band-aid; ABI mismatch may cause issues.

**Proper fix:** File upstream bug against the Waydroid image build. Reinit with `--system_type GAPPS` will not help because both types share the same `vendor.img`.

---

## cgroup-delegation.md

**Symptom:** `libprocessgroup: Failed to make and chown /sys/fs/cgroup/uid_*: Read-only file system` and `init: createProcessGroup(...) failed`

**Cause:** LXC config mounts cgroup read-only: `lxc.mount.auto = cgroup:ro sys:ro proc`.

**Verification:**
- `sudo cat /var/lib/waydroid/lxc/waydroid/config | grep 'mount.auto'`
- `sudo cat /sys/fs/cgroup/lxc.payload.waydroid/cgroup.subtree_control 2>/dev/null || echo 'NO_SUBTREE_CONTROL'`

**Fix:** Replace `cgroup:ro` with `cgroup:delegate` or add `lxc.cgroup2.delegate = 1`.

**Caution:** LXC 7.0.0 may reject `cgroup:delegate` with `Invalid filesystem to automount`. Test in a non-production session first.

---

## network-dhcp.md

**Symptom:** `waydroid status` shows `IP address: UNKNOWN` while container has connectivity.

**Cause:** `waydroid status` reads only `/var/lib/misc/dnsmasq.waydroid0.leases`. If that file is empty, status shows UNKNOWN even if the container already has an IP.

**Diagnosis:**
- `sudo ls -la /var/lib/misc/dnsmasq.waydroid0.leases`
- `sudo cat /var/lib/misc/dnsmasq.waydroid0.leases`
- `sudo dmesg | grep DEVICE-GUARD-BLOCK`

**Common blocker:** Host firewall/nftables `DEVICE-GUARD` may drop DHCP broadcasts from `waydroid0` before dnsmasq sees them.

**Fixes:**
1. Allow DHCP through firewall chain if safe.
2. Manually seed lease file with container MAC/IP.
3. Restart dnsmasq and trigger container DHCP renewal.

---

## rust-binder-regression.md

**Symptom:** `rust_binder: Failed to allocate buffer ... ENOSPC` and transaction failures on kernel >= 6.18.

**Cause:** Classic `CONFIG_ANDROID_BINDER_IPC` was replaced by `CONFIG_ANDROID_BINDER_IPC_RUST` in newer Arch kernels. The Rust driver had known large-transaction regressions in early releases.

**First-line path:** Do not custom-rebuild until checking whether the repo kernel already contains the fix.

1. Compare versions: `uname -r` vs `pacman -Q linux-zen`. **CRITICAL**: the running kernel often lags behind the installed package. If `uname -r` is older than `pacman -Q linux-zen`, the fix is already installed but not yet booted — just reboot.
2. Inspect running config: `zgrep ANDROID_BINDER_IPC /proc/config.gz`.
3. Inspect installed repo source: `/usr/lib/modules/<pacman-version>/build/drivers/android/binder/thread.rs` (NOT the running kernel's source). If `PointerFixupEntry` is already an enum with `Fixup` and `Skip` variants, commit `8e28c67` is present.
4. If the fix is present in the newer package, upgrade: `pacman -Syu linux-zen linux-zen-headers`, reboot, retest. No custom rebuild needed.

**Confirmed on 7.2.3.zen1-2 (2026-09):** `linux-zen 7.2.3.zen1-2` ships with the binder fix. The actual problem on this host was `uname -r` showed `7.2.2-zen1-1-zen` while `pacman -Q linux-zen` showed `7.2.3.zen1-2` — the package was already upgraded but the host had not been rebooted. `pacman -Syu` + reboot resolved it.

**Upstream fix:**
- Torvalds commit `8e28c67` (Darksonn/linux) — replaces the `skip == 0` sentinel with a proper `Fixup`/`Skip` enum in `drivers/android/binder/thread.rs`.
- Waydroid issue #2157
- Arch bug #173

**Patch location for custom rebuilds:** The fix touches `drivers/android/binder/thread.rs` only. When backporting, cherry-pick the full commit (it changes the `PointerFixupEntry` struct to an enum with `Fixup` and `Skip` variants, plus updates all call sites in `apply_and_validate_fixup_in_parent` and the fixup loop). Do not attempt to manually replicate the logic — the enum refactor is essential for correctness.

**Custom rebuild (only if repo package still lacks fix):**
If the repo package still lacks the fix (very unlikely on Arch >= 7.2.3), backport commit `8e28c67` into the installed source tree and rebuild. On this hardware, no simpler runtime workaround exists.

**Verification after upgrade:** After `pacman -Syu` and reboot, confirm with:
- `uname -r` shows the new version
- `zgrep ANDROID_BINDER_IPC_RUST /proc/config.gz` returns `=y`
- `waydroid status` shows container RUNNING
- `dmesg | grep rust_binder` shows no ENOSPC errors

**Verification after upgrade:** After `pacman -Syu` and reboot, confirm with:
- `uname -r` shows the new version
- `zgrep ANDROID_BINDER_IPC_RUST /proc/config.gz` returns `=y`
- `waydroid status` shows container RUNNING
- `dmesg | grep rust_binder` shows no ENOSPC errors

---

## upstream-reports.md

**Templates for submitting Waydroid/Arch issues.**

### Waydroid GitHub Issue Template

```
[BUG] <short title>

Description:
<what is broken>

Environment:
- Waydroid: <version>
- Image package: <package and version>
- Kernel: <version>

Expected:
<expected behavior>

Actual:
<actual behavior>

Suggested Fix:
<recommended change>

Logs:
<exact error lines>
```

### Arch Bug Template

```
Subject: [<package>] <short issue>

Description:
<issue summary>

Affected package: <name> <version>

Environment:
- Host: <distro>
- Kernel: <version>
- LXC/Waydroid versions

Suggested Fix:
<change/patch/version pin>

Logs:
<exact error lines>
```

### Garuda Forum Template

```
Subject: [Garuda] Waydroid <symptom>

Description:
<user-facing impact>

Symptoms:
- <bullet>

Environment:
- Garuda Linux
- Kernel: <version>
- waydroid <version>

Suggested Fix:
<command or config change>

Workaround:
<temporary mitigation>
```
