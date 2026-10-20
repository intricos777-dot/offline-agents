<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: standalone-iso-build
description: Build a standalone bootable ISO with custom kernel.
---

# Standalone ISO Build

Build a bootable ISO containing a compiled Linux kernel, initramfs, GRUB2 bootloader, and a zen-suite hardened security tooling stack. Target: Garuda Linux / Arch-based systems with linux-zen kernel.

## When to trigger

- User asks to build a bootable ISO with a custom kernel
- User asks to create a standalone kernel image for release
- User has a zen-suite or similar hardened tooling stack to package

## Workflow

1. **Prepare build environment** — install required packages:
   ```
   sudo pacman -S --noconfirm arch-install-scripts ccache bc kmod flex bison gcc xorriso syslinux
   ```
   Docker is NOT required — it fails with permission denied on docker.sock. Use pacstrap+xorriso directly.

2. **Prepare chroot** — use the existing arch-zen build script or pacstrap manually:
   ```
   sudo bash /home/livings/zen/zen-suite-gh/arch-zen/build.sh
   ```
   If build.sh fails, create chroot manually:
   ```
   sudo mkdir -p /home/livings/zen/zen-suite-gh/arch-zen/work/chroot
   sudo pacstrap -c /home/livings/zen/zen-suite-gh/arch-zen/work/chroot base linux linux-firmware
   ```

3. **Configure chroot** — critical for DNS resolution inside chroot:
   - Add `nameserver 8.8.8.8` to `${CHROOT}/etc/resolv.conf`
   - Add `Architecture = x86_64` to `${CHROOT}/etc/pacman.conf` [before any repo sections]
   - Add repo sections to pacman.conf: `[core]`, `[extra]`, `[multilib]` each with `Include = /etc/pacman.d/mirrorlist`
   - Write mirrorlist with working mirrors (test with `ping` first)

4. **Install packages in chroot**:
   ```
   sudo chroot ${CHROOT} pacman -Syu --noconfirm
   sudo chroot ${CHROOT} pacman -S --noconfirm --needed <packages from packages.txt>
   ```

5. **Copy Zen-Core modules** into chroot:
   ```
   sudo mkdir -p ${CHROOT}/opt/zen-core/modules
   sudo cp -a /home/livings/zen/linux-zen-suite/zen-core/modules/. ${CHROOT}/opt/zen-core/modules/
   sudo cp -a /home/livings/zen/linux-zen-suite/zen-core/. ${CHROOT}/opt/zen-core/
   ```

6. **Copy isolinux boot files** into chroot BEFORE building:
   ```
   sudo mkdir -p ${CHROOT}/isolinux
   sudo cp /usr/lib/syslinux/bios/isolinux.bin ${CHROOT}/isolinux/
   sudo cp /usr/lib/syslinux/bios/*.c32 ${CHROOT}/isolinux/ 2>/dev/null
   ```
   ⚠️ Boot file path is `/usr/lib/syslinux/bios/` NOT `/usr/lib/ISOLINUX/`. The old ISOLINUX path does not exist on this system.

7. **Unmount pseudo-filesystems** from chroot before xorriso:
   ```
   sudo umount -R ${CHROOT}/proc
   sudo umount -R ${CHROOT}/sys
   sudo umount -R ${CHROOT}/dev/pts
   sudo umount -R ${CHROOT}/dev/shm
   sudo umount -R ${CHROOT}/dev
   ```
   ⚠️ xorriso CANNOT graft files from mounted proc/sys — it fails with "Access to file is not allowed"

8. **Build ISO with xorriso** (not grub-mkrescue — no GRUB config in this setup):
   ```
   sudo xorriso -as mkisofs \
     -o arch-zen-$(date +%Y%m%d).iso \
     -isohybrid-mbr /usr/lib/syslinux/bios/isohdpfx.bin \
     -c isolinux/boot.cat \
     -b isolinux/isolinux.bin \
     -no-emul-boot -boot-load-size 4 -boot-info-table \
     -iso-level 3 -full-iso9660-filenames \
     -V "ARCH-ZEN" \
     ${CHROOT}
   ```
   ⚠️ Use `/usr/lib/syslinux/bios/isohdpfx.bin` for `-isohybrid-mbr` AND `-c isolinux/boot.cat` must reference a file that EXISTS in the chroot at `/isolinux/boot.cat`. If boot.cat is missing, xorriso fails with "Cannot find in ISO image".

9. **Verify ISO**:
   ```
   file arch-zen-*.iso  # should show: ISO 9660 CD-ROM filesystem data (DOS/MBR boot sector)
   xorriso -indev arch-zen-*.iso -report_el_torito plain 2>/dev/null | head -10
   ```

10. **Release to GitHub** — push to the linux-zen-suite repo:
    ```
    gh release create v1.2.0 arch-zen-*.iso --repo intricos777-dot/linux-zen-suite --title "Zen Suite v1.2.0" --notes "Bootable ISO with vulkan-shader-cache + AI coordination modules."
    ```

## Pitfalls

- **Docker builds fail on this system** — docker.sock permission denied. Use pacstrap+xorriso directly (step 3-8 above), not Docker. The `build-all.sh` script requires Docker and will fail.
- **DNS resolution inside chroot** — chroot resolv.conf is empty by default; add `nameserver 8.8.8.8` before running pacman inside chroot or all repo syncs fail with "Could not resolve host".
- **Architecture must be defined** — chroot pacman.conf needs `Architecture = x86_64` before any repo sections or pacman reports "no usable package repositories configured".
- **Pseudo-filesystems must be unmounted before xorriso** — mounted proc/sys/dev cause "Access to file is not allowed" graft failures. Always umount -R before building.
- **isolinux boot files must be in the chroot** — copy `isolinux.bin` and `.c32` files from `/usr/lib/syslinux/bios/` into `${CHROOT}/isolinux/` before xorriso. The `-c isolinux/boot.cat` path must resolve to an existing file inside the ISO image or xorriso aborts with "Cannot find in ISO image".
- **Boot file path is syslinux/bios not ISOLINUX** — `/usr/lib/ISOLINUX/isohdpfx.bin` does NOT exist on this system. Use `/usr/lib/syslinux/bios/isohdpfx.bin`.
- **mkinitcpio may fail in chroot** — dracut "call to execv failed (No such file or directory)" means dracut is missing or broken in the chroot. Skip mkinitcpio and rely on the host's initramfs if needed.
- **pacman download cache in chroot** — if pacman reports "not enough free disk space" inside chroot, create `${CHROOT}/var/cache/pacman/pkg/download` with proper permissions.
- **File ownership after sudo** — files created by sudo in the build directory will be root-owned; chown them back before ISO creation or the build may fail.
- **GRUB config must be inside the ISO** — the grub.cfg path relative to the ISO root matters; place it at `boot/grub/grub.cfg` within the ISO directory structure.
- **Verify the ISO is bootable** — run `xorriso -indev <iso> -ls /` to confirm the file structure before releasing.
- **Git LFS conflicts with force-push** — after `git pull --rebase` on an LFS-backed repo, if the rebase fails, `git rebase --abort` clears the rebase state. Force-push with `git push --force-with-lease origin master` to recover. The LFS objects persist in `.git/lfs/objects/` even after file resets — no need to re-download.
- **ISO module integration** — when adding TS/JS modules to the ISO's `zen-core/modules/` directory, ensure the `zen-manifest.json` lists them as integration points. The ISO build copies from the working tree, so modules must be present locally before xorriso.

## Integrating Custom Modules

When packaging hardened modules (like ai-coordination-server or vulkan-shader-cache) into the ISO:

1. Place `.ts`/`.js` module files under `zen-core/modules/`
2. Create a systemd service unit file (`*-service`) with strict sandboxing (see `arch-system-hardening/references/systemd-sandbox-hardening.md`)
3. Create an install script (`install-*.sh`) for first-boot deployment
4. Register in `zen-manifest.json` under `modules[]` and `integration_points[]`
5. Add a sample config (`sample-*.json`) if the module supports permutations
6. Test with `node modules/<name>.js` before ISO build
7. Rebuild ISO with `grub-mkrescue` (step 6 above)

## User preferences

- ISOs are released to `github.com/intricos777-dot/linux-zen-suite` as public releases
- Release notes should mention "compiled kernel and zen-suite hardened security stack"
- The zen-suite tooling includes: guard-wrapper, bde-patrol, local-function-guard, ollama-hardening, firefox/opera hardening
- Build artifacts go in `build/` subdirectory of the zen-suite repo, not the repo root