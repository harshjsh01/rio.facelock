# 🛠️ Omarchy Biometrics: Deep Technical Troubleshooting & Engineering Reference

This document provides a comprehensive technical log of all real-world engineering challenges, kernel bugs, bootloader edge cases, and filesystem behaviors discovered during the development and hardening of the **Omarchy Biometrics Suite**.

---

## 📑 Index of Solved Issues

1. [Issue 1: Double Lock Screen on Startup (Quickshell Race Condition)](#issue-1-double-lock-screen-on-startup)
2. [Issue 2: UKI (Unified Kernel Image) Black Screen on Boot](#issue-2-uki-unified-kernel-image-black-screen)
3. [Issue 3: Limine Bootloader Cmdline Drop-In Precedence Bug](#issue-3-limine-bootloader-cmdline-drop-in-precedence)
4. [Issue 4: `Invalid keyfile. Reverting to passphrase` LUKS Keyslot Mismatch](#issue-4-invalid-keyfile-reverting-to-passphrase)
5. [Issue 5: Systemd Emergency Mode Halt from VMware FUSE `auto_unmount`](#issue-5-systemd-emergency-mode-halt-from-vmware-fuse-auto_unmount)
6. [Issue 6: Snapshot Subvolume Drift & Missing Services](#issue-6-snapshot-subvolume-drift)

---

### Issue 1: Double Lock Screen on Startup

#### 🚨 Symptom
After logging in through SDDM with Face ID, the user lands on the Hyprland desktop only to find **another lock screen** immediately appearing over their workspace.

#### 🔍 Root Cause Analysis
During system startup, Quickshell's lock screen daemon initializes. If the Hyprland compositor starts slightly before logind marks the session as active, Quickshell executes `recoverStrandedLock()`, assuming an unclosed previous lock session and re-locking the screen.

#### 🔧 Exact Resolution
Patched `Service.qml` to verify session unlock tokens and ensure PAM states do not race with the initial display manager handoff:
```qml
// In Service.qml: prevent spurious stranded lock invocation during compositor launch
function checkInitialLockState() {
    if (sessionJustStarted && !pamState.isExplicitlyLocked) {
        return; // Skip lock engagement on initial login
    }
}
```

---

### Issue 2: UKI (Unified Kernel Image) Black Screen

#### 🚨 Symptom
After generating a UKI (`/boot/EFI/Linux/omarchy_linux.efi`), the system boots to a persistent black screen with no output or kernel panic.

#### 🔍 Root Cause Analysis
Omarchy's `limine-entry-tool` with `ENABLE_UKI=yes` bundled the kernel and initramfs into a single EFI PE binary, but failed to embed the complete `cryptdevice=PARTUUID=...:root` and `rootflags=subvol=@` command line into the UKI `.cmdline` section. Consequently, the kernel booted without knowing where the encrypted root device was located.

#### 🔧 Exact Resolution
Disabled UKI generation in `/etc/limine-entry-tool.d/omarchy-uki.conf` to restore the reliable separate kernel + initramfs architecture (`protocol: linux`):
```bash
sudo sed -i 's/ENABLE_UKI=yes/ENABLE_UKI=no/' /etc/limine-entry-tool.d/omarchy-uki.conf
sudo limine-mkinitcpio
```

---

### Issue 3: Limine Bootloader Cmdline Drop-In Precedence

#### 🚨 Symptom
Parameters written to `/etc/kernel/cmdline` were completely ignored by `limine-update`, leaving `/boot/limine.conf` with missing `cryptdevice=` flags.

#### 🔍 Root Cause Analysis
In `limine-entry-tool`, drop-in configs in `/etc/limine-entry-tool.d/*.conf` are evaluated alphabetically. The default file `omarchy-defaults.conf` used `KERNEL_CMDLINE[default]+=" quiet splash ..."`. Because it used the `+=` append operator before `KERNEL_CMDLINE[default]` was defined, the tool considered the variable initialized and completely bypassed reading `/etc/kernel/cmdline`.

#### 🔧 Exact Resolution
Created a prioritized drop-in file `00-cmdline.conf` that defines the base variable using the `=` assignment operator before any other drop-ins run:
```bash
echo 'KERNEL_CMDLINE[default]="cryptdevice=PARTUUID=bf15a18f-02:root root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs"' | sudo tee /etc/limine-entry-tool.d/00-cmdline.conf
sudo limine-update
```

---

### Issue 4: `Invalid keyfile. Reverting to passphrase`

#### 🚨 Symptom
During boot, the kernel text log printed:
```text
:: running hook [encrypt]
No key available with this passphrase.
Invalid keyfile. Reverting to passphrase.
Enter passphrase for /dev/sda2:
```

#### 🔍 Root Cause Analysis
The keyfile `/crypto_keyfile.bin` was embedded into the initramfs image, but it had **never been enrolled into the LUKS2 header**. Keyslot 0 was assigned to the user's passphrase and Keyslot 1 was assigned to the TPM 2.0 token. When `cryptsetup` tested `/crypto_keyfile.bin`, no keyslot matched the key bytes.

#### 🔧 Exact Resolution
Enrolled `/crypto_keyfile.bin` into LUKS Keyslot 2 using the master passphrase:
```bash
# 1. Create key with 000 permissions
sudo dd if=/dev/urandom of=/crypto_keyfile.bin bs=512 count=1 status=none
sudo chmod 000 /crypto_keyfile.bin

# 2. Enroll into LUKS2 keyslots
echo -n "YOUR_PASSPHRASE" > /tmp/p.key
sudo cryptsetup luksAddKey --key-file=/tmp/p.key /dev/sda2 /crypto_keyfile.bin
rm -f /tmp/p.key

# 3. Verify enrollment
sudo cryptsetup luksDump /dev/sda2
# (Keyslot 2 now contains the valid keyfile digest)
```

---

### Issue 5: Systemd Emergency Mode Halt from VMware FUSE `auto_unmount`

#### 🚨 Symptom
The system unlocked disk encryption instantly, but then abruptly halted at:
```text
[FAILED] Failed to mount /mnt/hgfs.
[DEPEND] Dependency failed for Local File Systems.
You are in emergency mode. Give root password for maintenance...
```

#### 🔍 Root Cause Analysis
The VMware Shared Folders mount entry in `/etc/fstab` contained:
`.host:/ /mnt/hgfs fuse.vmhgfs-fuse allow_other,auto_unmount,defaults 0 0`
In recent Linux kernels and FUSE versions, `auto_unmount` is an invalid parameter. The mount failed with exit status 32. Because the entry was missing the **`nofail`** flag, systemd treated `/mnt/hgfs` as a critical system partition and aborted the boot sequence.

#### 🔧 Exact Resolution
Patched `/etc/fstab` to remove `auto_unmount` and append `nofail`:
```bash
sudo sed -i 's/allow_other,auto_unmount,defaults/allow_other,defaults,nofail/' /etc/fstab
```

---

### Issue 6: Snapshot Subvolume Drift

#### 🚨 Symptom
After booting into a Snapper recovery snapshot (e.g., Snapshot #5), `systemctl status facelock-daemon` returns `Unit not found`, and `omarchy-shell lock status` returns `"faceUnlock": false`.

#### 🔍 Root Cause Analysis
Snapper snapshots are static, historical read-only snapshots of the `@` subvolume. When booting into a snapshot, any services installed or configured in the live `@` subvolume are absent from that historical point in time.

#### 🔧 Exact Resolution
1. Set the Btrfs default subvolume back to ID 256 (`@`):
   ```bash
   sudo btrfs subvolume set-default 256 /
   ```
2. In the Limine bootloader menu, always select the top entry:
   ```text
   ▶ Omarchy -> linux
   ```
   *(Only select Snapshots when repairing an unbootable system).*
