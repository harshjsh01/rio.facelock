# 👤 Omarchy Biometrics Suite: Face ID & Fingerprint

[![Platform](https://img.shields.io/badge/platform-Omarchy%20Linux%20%7C%20Arch%20Linux-green.svg)](https://omarchy.org)
[![Author](https://img.shields.io/badge/author-Harsh%20Joshi-blue.svg)](https://github.com)
[![License](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](LICENSE)

An enterprise-grade, high-accuracy **AI Face Unlock & Fingerprint Biometric Suite** crafted specifically for **Omarchy Linux** (Hyprland + Quickshell). Features an animated radar UI (`👀` $\to$ `😊`), sub-second recognition, and seamless integration with system PAM stacks (`sudo`, SDDM greeter, lock screen, and Polkit).

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
- **🛡️ External Root of Trust**: Pure user-space Quickshell plugin with zero mutable root scripts in the checkout. All system configurations rely strictly on root-owned, package-managed binaries.
- **🔒 Cold Boot Disk Security**: Full-disk encryption integrity is preserved unconditionally (guarded by master passphrase or motherboard TPM 2.0).

---

## 🚀 Installation & Setup

### 1. Install the Omarchy Plugin
Install and enable the desktop interface using the native Omarchy CLI:
```bash
omarchy plugin add https://github.com/harshjsh01/rio.facelock --enable
```

### 2. Install the Core Biometric Dependencies
Install the package-managed AI face recognition backend:
```bash
yay -S --needed facelock-bin onnxruntime-cpu
```

### 3. Initialize Face Authentication
Configure the system daemon and enroll your biometric model using the package-signed `/usr/bin/facelock` tool:
```bash
# 1. Initialize daemon and configure PAM stacks
sudo facelock setup

# 2. Enroll your face (look at your camera with normal room lighting)
sudo facelock enroll $USER

# 3. (Optional) Verify biometric detection in terminal
sudo facelock test $USER
```

---

## 👆 Hardware Fingerprint Integration (Optional)

If your laptop or workstation is equipped with a supported fingerprint scanner:

```bash
# 1. Install and enable the fingerprint daemon
sudo pacman -S --needed fprintd
sudo systemctl enable --now fprintd.service

# 2. Enroll your fingerprint
fprintd-enroll -f right-index-finger $USER

# 3. Verify enrolled fingerprint
fprintd-verify $USER
```

---

## ⌨️ Daily Usage

* **Lock Screen**: Press <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>L</kbd> &rarr; Look at your webcam &rarr; Instant unlock!
* **Terminal Admin**: Run `sudo pacman -Syu` &rarr; Camera verifies your face &rarr; Admin elevation granted without password entry.
* **Password Fallback**: Type your user password at any time if the camera is obstructed or in low-light conditions.

---

## 🛡️ Security & Threat Model

1. **Pure Desktop Extension Boundary**:
   - The plugin checkout contains zero mutable shell scripts executing privileged actions.
   - All privileged operations are executed exclusively through system-owned, package-verified binaries (`/usr/bin/facelock` and `pacman`), providing an immutable external root of trust.
2. **Encrypted Biometric Storage**:
   - Facial feature embeddings are stored inside the encrypted root filesystem and protected with AES-256-GCM.
3. **Fail-Closed Biometrics**:
   - Any biometric mismatch, camera disconnection, or timeout immediately requires standard master password authentication.

---

## 📜 Credits & License

* **Author**: Harsh Joshi
* **License**: GPL-3.0
* **Designed for**: [Omarchy Linux](https://omarchy.org)
