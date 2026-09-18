# Building a Bootable ISO from zen-suite

## Workflow

1. **Assemble ISO staging directory**
   ```bash
   mkdir -p /tmp/zen-iso/{boot/grub,zen-suite}
   cp /boot/vmlinuz-linux-zen /tmp/zen-iso/boot/
   cp /boot/initramfs-linux-zen.img /tmp/zen-iso/boot/
   cp /boot/initramfs-linux-zen-fallback.img /tmp/zen-iso/boot/
   cp -r /home/sin/Projects/polsia/businesses/linux-zen-build/zen-suite/zen-core/* /tmp/zen-iso/zen-suite/
   ```

2. **Write GRUB config** (`/tmp/zen-iso/boot/grub/grub.cfg`)
   - Three entries: latest kernel, fallback kernel, rescue shell (single-user)
   - Use `root=/dev/sr0 ro quiet` for live boot

3. **Build the ISO**
   ```bash
   sudo grub-mkrescue /tmp/zen-iso -o /home/sin/zen-suite-bootable.iso
   ```
   Produces a hybrid El-Torito + MBR bootable ISO (~353 MB with kernel + initramfs).

4. **Verify**
   ```bash
   file /home/sin/zen-suite-bootable.iso    # "ISO 9660 CD-ROM filesystem data (DOS/MBR boot sector) ... bootable"
   isosize /home/sin/zen-suite-bootable.iso
   xorriso -indev /home/sin/zen-suite-bootable.iso -ls /
   ```

## ISO Contents Layout
   ```
   /boot/vmlinuz-zen
   /boot/initramfs-zen.img
   /boot/initramfs-zen-fallback.img
   /boot/grub/grub.cfg
   /zen-suite/          (zen-core tooling: guard-wrapper, bde-patrol, local-function-guard, hardening configs)
   ```

## Pitfalls

- **`grub-mkrescue` requires `grub-common` and `xorriso`** — install both via `sudo pacman -S grub-bios syslinux xorriso`
- **`/boot/initramfs-*.img` are root-owned** — use `sudo cp` to copy them into the staging dir
- **ISO >100 MB won't push to GitHub** — use `git lfs track "*.iso"` or create a GitHub release asset instead of committing the ISO to the repo
- **GRUB config `root=/dev/sr0`** only works for live/bootable ISOs; for installed systems use the actual root device or UUID
- **`grub-install` fails in non-root sessions** — `grub-mkrescue` handles bootloader embedding automatically; skip manual `grub-install`
