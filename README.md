# 👤 Omarchy Biometrics Suite: Face ID & Fingerprint

[![Platform](https://img.shields.io/badge/platform-Omarchy%20Linux%20%7C%20Arch%20Linux-green.svg)](https://omarchy.org)
[![Author](https://img.shields.io/badge/author-Harsh%20Joshi-blue.svg)](https://github.com)
[![License](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](LICENSE)

An enterprise-grade, high-accuracy **AI Face Unlock & Fingerprint Biometric Suite** crafted specifically for **Omarchy Linux** (Hyprland + Quickshell). Features a modern animated radar UI (`👀` $\to$ `😊`), sub-second recognition, full PAM integration (`sudo`, lock screen, SDDM greeter, Polkit), and strict supply-chain cryptographic verification.

---

## 🏛️ Enterprise Security Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ ENTERPRISE BIOMETRIC MODEL (Apple / Windows Hello / Android Standard)    │
├─────────────────────────────────────────────────────────────────────────────┤
│ • Power On ──► [Disk Encryption Passphrase / TPM 2.0] ──► Decrypted Root   │
│ • SDDM Greeter / Login Screen ─────────► AI Face ID + Fingerprint           │
│ • Quickshell Lock Screen (<Super+Ctrl+L>) ► AI Face ID + Fingerprint + PIN │
│ • Terminal 'sudo' / Admin Elevation ───► AI Face ID + Fingerprint           │
│ • Graphical Polkit Elevation Dialogs ──► AI Face ID + Fingerprint           │
└─────────────────────────────────────────────────────────────────────────────┘
```

> [!NOTE]
> **Biometrics and Cold Boot Storage:**
> Camera hardware drivers, USB subsystems, ONNX AI neural network runtimes, and trained biometric face embeddings reside inside the encrypted filesystem. They execute securely once the system is booted and the volume is decrypted. Cold-boot storage remains protected by your LUKS master passphrase or motherboard TPM 2.0 measured boot.

---

## 🛡️ Security Architecture & Threat Model

1. **Privileged Installation from Root-Owned Snapshot**:
   - Privileged installation steps (PAM stack insertion, D-Bus system policies, service activation) execute exclusively from an isolated, root-owned staging directory (`/run/rio-facelock-installer/`, permissions `0700`, owner `root:root`).
   - The SHA-256 digest of the staged script (`install-privileged.sh`) is cryptographically authenticated against a reviewed, pinned constant before any root action is permitted.
   - This eliminates user-writable script race conditions (TOCTOU attacks) and unauthorized in-place modifications.

2. **Immutable Package Binding & Strict Fail-Closed Verification**:
   - Dependencies are pinned to an immutable upstream release and commit:
     - `facelock-bin`: version `0.1.4-1` (git commit `2a3cec6462cdd0ee7ca3bc352dfeb8b46ab2f7f5`)
     - PKGBUILD SHA-256: `820aaa652284a0c3328048d635e4b6a8320a2c12b858270c2f9bfbcdf1cc3f8b`
     - `onnxruntime-cpu`: official Arch Linux repository package (GPG signed)
   - Every privileged binary is strictly validated against pinned reference SHA-256 baselines before registration with PAM:
     - `/usr/lib/security/pam_facelock.so`: `ca4e525b1a70fbb620e47af81b6df3bfd90166c260b546ea846fd8ca8f8da1a3`
     - `/usr/bin/facelock`: `b87dbf72540f3aa90b8682cb0c7efefec2c9643cf09d8da4a036a34b5bc8061e`
     - `/usr/bin/facelock-polkit-agent`: `17a11c9c8dbf8c09cc6eb3e27775cb6193b18c8727e4c648bd23ac0fdfd6fceb`
   - **Fail-Closed Policy**: If any binary is missing, unverified, or mismatched, setup halts immediately and initiates an automated rollback. No interactive overrides are permitted.

3. **No Plaintext Disk Keyfiles**:
   - Full disk encryption security is maintained unconditionally. No plaintext unlock keys or reusable keyfiles are ever embedded into `initramfs` or `/boot`.

4. **Transactional Pre-Flight Backups & Rollback**:
   - Backups of `/etc/pam.d/sudo`, `/etc/pam.d/sddm`, and `/etc/pam.d/polkit-1` are stored in `/etc/omarchy/backup/rio.facelock/`.
   - Complete uninstallation and restoration can be executed at any time via `./setup.sh --remove`.

---

## ✨ Features

- **🧠 Neural Network AI Engine**: Powered by lightweight ONNX neural models with hardware-accelerated feature extraction.
- **⚡ Sub-Second Recognition**: Average authentication latency of **0.8s – 1.7s** with liveness verification.
- **🎨 Custom Omarchy Quickshell UI**: Pulsing radar scanner (`👀`), green success state (`😊`), fingerprint indicator, and seamless password fallback.
- **👆 Dual Biometric Stack**: Seamlessly integrates Face ID (`facelock`) and Fingerprint (`fprintd`) into a unified PAM pipeline.
- **🛡️ Stranded Lock Prevention**: Atomic lock state machine prevents lock screen desynchronization.
- **🔒 Periodic Password Re-verification**: Configurable policy requiring master password verification every 7 days.

---

## 🚀 Quick Installation

### Option 1: Native Omarchy Plugin CLI (Recommended)
```bash
omarchy plugin add https://github.com/harshjsh01/rio.facelock.git --enable
~/.config/omarchy/plugins/rio.facelock/setup.sh
```

### Option 2: Direct Git Clone
```bash
git clone https://github.com/harshjsh01/rio.facelock.git ~/.config/omarchy/plugins/rio.facelock
cd ~/.config/omarchy/plugins/rio.facelock
./setup.sh
```

---

## 🔧 Management & CLI Options

```bash
# Non-destructive inspection of biometrics, services, and PAM status
./setup.sh --check

# Complete uninstallation, PAM restoration, and system rollback
./setup.sh --remove

# View help and usage
./setup.sh --help
```

---

## 📸 Manual Biometrics Commands

### 1. Face ID Commands
```bash
# Enroll your face (sit in normal lighting, look at camera)
sudo facelock enroll $USER

# Test face verification in terminal
sudo facelock test $USER

# Check daemon status
systemctl status facelock-daemon
```

### 2. Fingerprint Commands
```bash
# List available fingerprint readers
fprintd-list $USER

# Enroll your right index finger
fprintd-enroll -f right-index-finger $USER

# Verify enrolled fingerprint
fprintd-verify $USER
```

---

## ⌨️ How to Use Daily

* **Lock Screen**: Press <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>L</kbd> &rarr; Look at your webcam &rarr; Instant unlock!
* **Terminal Admin**: Type `sudo pacman -Syu` &rarr; Camera light blinks &rarr; Authenticated without typing your password!
* **Password Fallback**: Simply type your password at any time if camera is covered or in pitch-dark environments.

---

## 📜 Credits & License

* **Author**: Harsh Joshi
* **License**: GPL-3.0
* **Designed for**: [Omarchy Linux](https://omarchy.org)
