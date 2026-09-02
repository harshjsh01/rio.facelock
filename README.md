# 👤 Omarchy Biometrics Suite: Face ID & Fingerprint

[![Platform](https://img.shields.io/badge/platform-Omarchy%20Linux%20%7C%20Arch%20Linux-green.svg)](https://omarchy.org)
[![Author](https://img.shields.io/badge/author-Harsh%20Joshi-blue.svg)](https://github.com)
[![License](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](LICENSE)

An enterprise-grade, high-accuracy **AI Face Unlock & Fingerprint Biometric Suite** crafted specifically for **Omarchy Linux** (Hyprland + Quickshell). Features a modern animated radar UI (`👀` $\to$ `😊`), sub-second recognition, full PAM integration (`sudo`, lock screen, SDDM), and support for both physical hardware and virtual machines.

---

## 🏛️ Security Architectures Explained

When configuring biometric security on Linux, there are two distinct architectural models depending on your threat model and hardware environment:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ METHOD 1: High Security (Apple / Windows Hello / Android Model)          │
├─────────────────────────────────────────────────────────────────────────────┤
│ • Power On ──► [Disk Password / TPM] ──► Direct to Desktop (SDDM Autologin) │
│ • Lock Screen (<Super+Ctrl+L>) ────────► AI Face ID + Fingerprint + PIN     │
│ • Terminal 'sudo' / Admin Elevation ───► AI Face ID + Fingerprint           │
│ • Graphical Polkit Dialogs ────────────► AI Face ID + Fingerprint           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ ⚡ METHOD 2: Maximum Convenience (Direct Face ID on Power-On)               │
├─────────────────────────────────────────────────────────────────────────────┤
│ • Power On ──► Silent Auto-Unlock ───► [SDDM Login Screen with Face ID]     │
│ • Lock Screen (<Super+Ctrl+L>) ────────► AI Face ID + Fingerprint + PIN     │
│ • Terminal 'sudo' / Admin Elevation ───► AI Face ID + Fingerprint           │
│ • Graphical Polkit Dialogs ────────────► AI Face ID + Fingerprint           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔒 Enterprise Security Comparison

| Feature / Attack Vector | Method 1 (High Security) | Method 2 (Max Convenience) | Apple macOS / iOS | Windows 11 Hello | Android Knox |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Physical Laptop Theft** | 🛡️ **Protected** (AES-256) | ⚠️ **Vulnerable** (Disk unencrypted/auto-unlocked) | 🛡️ Protected (FileVault) | 🛡️ Protected (BitLocker) | 🛡️ Protected |
| **Direct SSD Removal & Extraction** | 🛡️ **Unreadable** | ⚠️ **Readable** on external PC | 🛡️ Unreadable | 🛡️ Unreadable | 🛡️ Unreadable |
| **In-Person Desktop Security** | 🛡️ **Face ID / PIN** | 🛡️ **Face ID / PIN** | 🛡️ Face ID / Touch ID | 🛡️ Face ID / Fingerprint | 🛡️ Biometrics |
| **Terminal `sudo` Admin Elevation** | 🛡️ **Face ID** | 🛡️ **Face ID** | 🛡️ Touch ID | 🛡️ Windows Hello | 🛡️ Biometrics |
| **Recommended Environment** | Physical Laptops, Travel | Home Desktops, Virtual Machines | Apple Hardware | Windows Hardware | Mobile Devices |

> [!NOTE]
> **Why doesn't Face ID unlock the hard drive directly on cold boot?**
> Camera hardware drivers, USB subsystems, ONNX AI neural network runtimes, and trained biometric face embeddings are stored **inside the encrypted filesystem**. They cannot physically execute until the root filesystem is decrypted. This is why **Apple, Windows Hello, and Android** all require a master passphrase/PIN on initial power-on before biometric sensors are initialized into memory.

---

## ✨ Features

- **🧠 Neural Network AI Engine**: Powered by lightweight ONNX neural models (`insightface` / `facelock`) with hardware-accelerated feature extraction.
- **⚡ Sub-Second Recognition**: Average authentication time of **0.8s – 1.7s** with liveness verification.
- **🎨 Custom Omarchy Quickshell UI**: Pulsing radar scanner (`👀`), green success state (`😊`), fingerprint indicator (`👆`), and seamless password fallback.
- **👆 Dual Biometric Stack**: Combines Face ID (`facelock`) and Fingerprint (`fprintd`) in a unified PAM pipeline.
- **🛡️ Stranded Lock Prevention**: Zero-race condition state machine prevents double lock screens on startup.
- **🔒 Weekly Password Check**: Built-in security policy enforces master password verification once every 7 days.

---

## 🚀 Quick Installation

Run the interactive setup wizard:

```bash
cd ~/.config/omarchy/plugins/rio.facelock
chmod +x setup.sh
./setup.sh
```

The installer will automatically:
1. Detect your webcam (`/dev/video0`) and fingerprint reader.
2. Install required AI neural libraries (`facelock-bin`, `onnxruntime-cpu`).
3. Guide you through selecting **Method 1 (High Security)** or **Method 2 (Convenience)**.
4. Auto-patch VMware shared folder FUSE options if running inside a virtual machine.
5. Launch the high-resolution face enrollment tool.

---

## 📸 Manual Biometrics Management

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

* **Author**: Rio
* **License**: GPL-3.0
* **Designed for**: [Omarchy Linux](https://omarchy.org)
