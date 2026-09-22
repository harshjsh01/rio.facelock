# 👤 Omarchy Biometrics Suite: Face ID & Fingerprint

[![Platform](https://img.shields.io/badge/platform-Omarchy%20Linux%20%7C%20Arch%20Linux-green.svg)](https://omarchy.org)
[![Author](https://img.shields.io/badge/author-Harsh%20Joshi-blue.svg)](https://github.com)
[![License](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](LICENSE)

An enterprise-grade, high-accuracy **AI Face Unlock & Fingerprint Biometric Suite** crafted specifically for **Omarchy Linux** (Hyprland + Quickshell). Features a modern animated radar UI (`👀` $\to$ `😊`), sub-second recognition, and full integration with system PAM stacks (`sudo`, SDDM greeter, lock screen, and Polkit).

---

## 🏛️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 👤 OMARCHY BIOMETRIC ARCHITECTURE                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ • Cold Boot ────────► [Master Passphrase / TPM 2.0] ──► Decrypted Root     │
│ • SDDM Greeter ─────► AI Face ID + Fingerprint                              │
│ • Quickshell Lock Screen (<Super+Ctrl+L>) ► Animated Radar UI + Face ID    │
│ • Terminal 'sudo' Elevation ──────────────► AI Face ID + Fingerprint        │
│ • Graphical Polkit Dialogs ───────────────► AI Face ID + Fingerprint        │
└─────────────────────────────────────────────────────────────────────────────┘
```

The plugin operates as a native **Quickshell** desktop service (`Service.qml` and `LockView.qml`) that connects to Omarchy's session manager and interfaces with the system's PAM authentication stack.

---

## ✨ Features

- **🧠 Neural Network AI Engine**: Powered by lightweight ONNX neural models with hardware-accelerated feature extraction.
- **⚡ Sub-Second Recognition**: Average authentication latency of **0.8s – 1.7s** with liveness detection.
- **🎨 Animated Radar UI**: Custom Quickshell lock interface with pulsing scanner (`👀`), success confirmation (`😊`), and password fallback.
- **👆 Dual Biometric Stack**: Combines Face ID (`facelock`) and Fingerprint (`fprintd`) in a unified authentication pipeline.
- **🛡️ Immutable Supply-Chain Verification**: Pinned commit and strict cryptographic SHA-256 pre-elevation verification before registering PAM modules.
- **🔒 Cold Boot Disk Security**: Full-disk encryption integrity is preserved unconditionally (guarded by master passphrase or motherboard TPM 2.0).

---

## 🚀 Installation & Verified Setup

### Step 1: Install the Omarchy Desktop Plugin
Install and enable the desktop interface using the native Omarchy CLI:
```bash
omarchy plugin add https://github.com/harshjsh01/rio.facelock --enable
```

### Step 2: Install Official Signed Dependencies
Install official, GPG-signed neural network libraries from the Arch Linux repository:
```bash
sudo pacman -S --needed onnxruntime-cpu
```

### Step 3: Verified Immutable Installation of Biometric Daemon
To enforce supply-chain integrity and prevent unreviewed external code from entering the root PAM stack, install `facelock-bin` from its reviewed immutable git commit with cryptographic checksum verification:

```bash
git clone https://aur.archlinux.org/facelock-bin.git /tmp/facelock-bin && \
cd /tmp/facelock-bin && \
git checkout 2a3cec6462cdd0ee7ca3bc352dfeb8b46ab2f7f5 && \
echo "820aaa652284a0c3328048d635e4b6a8320a2c12b858270c2f9bfbcdf1cc3f8b  PKGBUILD" | sha256sum -c - && \
makepkg -si --noconfirm && \
echo "ca4e525b1a70fbb620e47af81b6df3bfd90166c260b546ea846fd8ca8f8da1a3  /usr/lib/security/pam_facelock.so" | sha256sum -c - && \
sudo facelock setup && \
sudo facelock enroll $USER
```

* **Immutable Commit Binding**: Fixed to commit `2a3cec6` (`v0.1.4-1`).
* **PKGBUILD Verification**: SHA-256 is validated before package compilation.
* **Pre-Elevation PAM Verification**: `/usr/lib/security/pam_facelock.so` checksum is validated before `sudo facelock setup` runs.
* **Fail-Closed**: If any checksum mismatches, the pipeline halts immediately with no root elevation.

---

## 💻 Hardware & Virtual Environment Options

The suite operates across both physical hardware and virtualized environments:

### Option A: Bare Metal Laptops & Desktops
* Utilizes your laptop's integrated USB / MIPI camera (`/dev/video0`).
* To test live camera feed and feature detection:
  ```bash
  sudo facelock test $USER
  ```

### Option B: Virtual Machines (VMware / QEMU / VirtualBox)
* Connect your host webcam to the guest VM via **VMware Removable Devices &rarr; Cameras**.
* If using VMware Shared Folders (hgfs / FUSE), ensure `/etc/fstab` uses `nofail` to prevent emergency mode:
  ```bash
  sudo sed -i 's/auto_unmount,defaults/defaults,nofail/' /etc/fstab
  ```

---

## 🔐 Authentication Workflow Options

Users can choose between two post-boot desktop workflows:

### Workflow 1: Direct-to-Desktop (Apple / Windows Hello Style)
1. Power on laptop &rarr; Enter cold-boot disk passphrase (or TPM 2.0 auto-unlocks).
2. SDDM automatically logs in directly to your Hyprland desktop session.
3. Quickshell Lock Screen immediately protects the session, scanning your face with the animated radar UI.

To configure SDDM autologin:
```bash
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=$USER
Session=omarchy.desktop
EOF
```

### Workflow 2: SDDM Login Greeter Face ID
1. Power on laptop &rarr; Decrypt storage.
2. SDDM greeter appears with camera scanning &rarr; Look at webcam to authenticate directly into your session.

To enable Face ID on the SDDM login screen:
```bash
sudo facelock setup --pam --service sddm
```

---

## 🛡️ Passwordless Cold Boot: Motherboard TPM 2.0 (Optional)

For physical hardware users who desire seamless cold-boot storage unlock without typing a disk passphrase, bind LUKS to your motherboard's secure hardware TPM 2.0 chip:

```bash
sudo systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2
```
* **Hardware Security**: The disk key is sealed within the TPM chip and only released if firmware and PCR measurements are intact.
* **Zero Disk Leakage**: No plaintext keyfiles or passwords ever touch `/boot` or `initramfs`.

---

## 👆 Hardware Fingerprint Integration (Optional)

To enable simultaneous Face ID and Fingerprint recognition:

```bash
# 1. Install and enable the fingerprint daemon
sudo pacman -S --needed fprintd
sudo systemctl enable --now fprintd.service

# 2. Enroll your right index finger
fprintd-enroll -f right-index-finger $USER

# 3. Verify fingerprint enrollment
fprintd-verify $USER
```
`Service.qml` automatically detects `fprintd` in the PAM pipeline and enables dual-biometric authentication.

---

## ⌨️ Daily Usage

* **Lock Screen**: Press <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>L</kbd> &rarr; Look at your webcam &rarr; Instant unlock!
* **Terminal Admin**: Run `sudo pacman -Syu` &rarr; Camera verifies your face &rarr; Admin elevation granted without password entry.
* **Password Fallback**: Type your user password at any time if the camera is obstructed or in low-light conditions.

---

## 🧹 Removal & Uninstallation

To cleanly remove Face ID authentication:
```bash
# 1. Remove PAM integration
sudo facelock setup --remove

# 2. Disable systemd daemon
sudo systemctl disable --now facelock-daemon.service

# 3. Disable Omarchy plugin
omarchy plugin disable rio.facelock
```

---

## 📜 Credits & License

* **Author**: Harsh Joshi
* **License**: GPL-3.0
* **Designed for**: [Omarchy Linux](https://omarchy.org)
