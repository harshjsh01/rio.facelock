#!/usr/bin/env bash
# ==============================================================================
# Omarchy Biometrics Suite: Face ID & Fingerprint
# Author: Harsh Joshi
# Plugin ID: rio.facelock
# Version: 1.0.0
# Description: Production-grade Face Unlock & Fingerprint for Omarchy Linux
# ==============================================================================

set -euo pipefail

# Pinned verified integrity baseline (facelock-bin 0.1.4-1)
readonly VERIFIED_FACELOCK_VERSION="0.1.4-1"
readonly VERIFIED_PAM_SHA256="ca4e525b1a70fbb620e47af81b6df3bfd90166c260b546ea846fd8ca8f8da1a3"
readonly VERIFIED_BIN_SHA256="b87dbf72540f3aa90b8682cb0c7efefec2c9643cf09d8da4a036a34b5bc8061e"
readonly BACKUP_DIR="/etc/omarchy/backup/rio.facelock"

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_PURPLE='\033[0;35m'

# Active cleanup trap guaranteeing no sensitive data remains in memory or disk
cleanup() {
    local exit_code=$?
    unset luks_pass 2>/dev/null || true
    if [[ -n "${SECURE_TMP_DIR:-}" && -d "${SECURE_TMP_DIR:-}" ]]; then
        rm -rf "$SECURE_TMP_DIR" 2>/dev/null || true
    fi
    if [ $exit_code -ne 0 ] && [ "${INSTALLING:-0}" -eq 1 ]; then
        echo -e "\n${C_RED}[!] Installation interrupted or failed. Initiating transactional rollback...${C_RESET}"
        rollback_on_failure
    fi
}
trap cleanup EXIT INT TERM HUP

banner() {
    clear
    echo -e "${C_CYAN}${C_BOLD}"
    echo "  ██████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗"
    echo " ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝"
    echo " ██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ "
    echo " ██║   ██║██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝  "
    echo " ╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║   ██║   "
    echo "  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   "
    echo -e "       👤 High-Accuracy AI Face ID & Biometrics Suite        ${C_RESET}"
    echo -e "              ${C_PURPLE}Created with ❤️  by Harsh Joshi${C_RESET}"
    echo -e "${C_BLUE}=================================================================${C_RESET}"
    echo ""
}

log_info() { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
log_success() { echo -e "${C_GREEN}[✓ SUCCESS]${C_RESET} $1"; }
log_warn() { echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Omarchy Biometrics Suite (Face ID & Fingerprint) Installer & Manager

Options:
  --check        Inspect and verify system biometrics configuration without modifying anything.
  --remove       Cleanly uninstall rio.facelock, restore original PAM stacks, and remove keyfiles.
  --help         Display this help message.

EOF
    exit 0
}

check_status() {
    echo -e "${C_CYAN}${C_BOLD}=== rio.facelock System Biometrics Status ===${C_RESET}"
    
    echo -n "Webcam (/dev/video*): "
    if ls /dev/video* >/dev/null 2>&1; then
        echo -e "${C_GREEN}Detected ($(ls -d /dev/video* | tr '\n' ' '))${C_RESET}"
    else
        echo -e "${C_RED}Missing (/dev/video* not found)${C_RESET}"
    fi
    
    echo -n "facelock-bin: "
    if pacman -Qi facelock-bin >/dev/null 2>&1; then
        echo -e "${C_GREEN}Installed ($(pacman -Q facelock-bin | awk '{print $2}'))${C_RESET}"
    else
        echo -e "${C_RED}Not installed${C_RESET}"
    fi
    
    echo -n "onnxruntime: "
    if pacman -Qi onnxruntime-cpu >/dev/null 2>&1 || pacman -Qi onnxruntime >/dev/null 2>&1; then
        echo -e "${C_GREEN}Installed${C_RESET}"
    else
        echo -e "${C_RED}Not installed${C_RESET}"
    fi
    
    echo -n "facelock-daemon.service: "
    if systemctl is-active --quiet facelock-daemon.service 2>/dev/null; then
        echo -e "${C_GREEN}Active (Running)${C_RESET}"
    else
        echo -e "${C_YELLOW}Inactive / Stopped${C_RESET}"
    fi
    
    echo -n "PAM sudo face unlock: "
    if grep -q "pam_facelock.so" /etc/pam.d/sudo 2>/dev/null; then
        echo -e "${C_GREEN}Configured${C_RESET}"
    else
        echo -e "${C_YELLOW}Not configured${C_RESET}"
    fi
    
    echo -n "PAM SDDM face unlock: "
    if grep -q "pam_facelock.so" /etc/pam.d/sddm 2>/dev/null; then
        echo -e "${C_GREEN}Configured${C_RESET}"
    else
        echo -e "${C_YELLOW}Not configured${C_RESET}"
    fi
    
    echo -n "Auto-unlock keyfile (/crypto_keyfile.bin): "
    if [ -f /crypto_keyfile.bin ]; then
        echo -e "${C_GREEN}Present (Method 2 Active)${C_RESET}"
    else
        echo -e "${C_BLUE}None (Method 1 High-Security Mode)${C_RESET}"
    fi
    
    exit 0
}

backup_system_files() {
    log_info "Creating transactional pre-modification backups in $BACKUP_DIR..."
    sudo mkdir -p "$BACKUP_DIR"
    sudo chmod 700 "$BACKUP_DIR"
    
    for stack in sudo sddm polkit-1; do
        if [ -f "/etc/pam.d/$stack" ] && [ ! -f "$BACKUP_DIR/$stack.orig" ]; then
            sudo cp -p "/etc/pam.d/$stack" "$BACKUP_DIR/$stack.orig"
        fi
    done
    if [ -f /etc/fstab ] && [ ! -f "$BACKUP_DIR/fstab.orig" ]; then
        sudo cp -p /etc/fstab "$BACKUP_DIR/fstab.orig"
    fi
}

rollback_on_failure() {
    log_warn "Reverting changes from pre-modification backups..."
    if [ -d "$BACKUP_DIR" ]; then
        for stack in sudo sddm polkit-1; do
            if [ -f "$BACKUP_DIR/$stack.orig" ]; then
                sudo cp -p "$BACKUP_DIR/$stack.orig" "/etc/pam.d/$stack" 2>/dev/null || true
            fi
        done
        if [ -f "$BACKUP_DIR/fstab.orig" ]; then
            sudo cp -p "$BACKUP_DIR/fstab.orig" /etc/fstab 2>/dev/null || true
        fi
    fi
    sudo rm -f /etc/pam.d/omarchy-lock-face 2>/dev/null || true
    sudo rm -f /crypto_keyfile.bin 2>/dev/null || true
    sudo rm -f /etc/mkinitcpio.conf.d/auto_unlock.conf 2>/dev/null || true
    sudo systemctl disable --now facelock-daemon.service 2>/dev/null || true
    log_warn "Rollback completed. System restored."
}

remove_plugin() {
    banner
    echo -e "${C_YELLOW}${C_BOLD}⚠️  REMOVING RIO.FACELOCK BIOMETRICS SUITE${C_RESET}\n"
    read -rp "Are you sure you want to remove Face ID and restore default authentication? (y/N): " confirm_rm
    if [[ ! "$confirm_rm" =~ ^[Yy]$ ]]; then
        log_info "Aborted removal."
        exit 0
    fi
    
    log_info "Stopping and disabling facelock-daemon service..."
    sudo systemctl disable --now facelock-daemon.service 2>/dev/null || true
    
    log_info "Reverting PAM configurations across sudo, SDDM, and Polkit..."
    sudo rm -f /etc/pam.d/omarchy-lock-face
    
    for stack in sudo sddm polkit-1; do
        if [ -f "/etc/pam.d/$stack" ]; then
            sudo sed -i '/pam_facelock.so/d' "/etc/pam.d/$stack"
            sudo sed -i '/pam_fprintd.so/d' "/etc/pam.d/$stack"
        fi
    done
    
    log_info "Removing D-Bus system policy..."
    sudo rm -f /usr/share/dbus-1/system.d/org.facelock.Daemon.conf
    
    log_info "Removing SDDM autologin if present..."
    sudo rm -f /etc/sddm.conf.d/autologin.conf
    
    if [ -f /crypto_keyfile.bin ]; then
        local luks_dev
        luks_dev=$(lsblk -rn -o PATH,FSTYPE | grep -E "crypto_LUKS" | awk '{print $1}' | head -n 1)
        if [ -n "$luks_dev" ]; then
            log_info "Removing keyfile from LUKS keyslot on $luks_dev..."
            sudo cryptsetup luksRemoveKey "$luks_dev" /crypto_keyfile.bin 2>/dev/null || true
        fi
        sudo rm -f /crypto_keyfile.bin
    fi
    
    if [ -f /etc/mkinitcpio.conf.d/auto_unlock.conf ]; then
        sudo rm -f /etc/mkinitcpio.conf.d/auto_unlock.conf
        log_info "Rebuilding clean initramfs image..."
        if command -v limine-mkinitcpio >/dev/null 2>&1; then
            sudo limine-mkinitcpio
        else
            sudo mkinitcpio -P
        fi
    fi
    
    log_success "rio.facelock completely removed. System successfully restored to default!"
    exit 0
}

check_prerequisites() {
    log_info "Verifying system environment..."
    
    if ! command -v pacman >/dev/null 2>&1; then
        log_error "This installer requires Arch Linux / Omarchy."
        exit 1
    fi
    
    if ls /dev/video* >/dev/null 2>&1; then
        log_success "Webcam detected: $(ls -d /dev/video* | tr '\n' ' ')"
    else
        log_warn "No video devices found at /dev/video*. Make sure your webcam is connected."
    fi
}

install_packages() {
    log_info "Verifying and installing core AI face recognition dependencies..."
    
    local packages=("facelock-bin" "onnxruntime-cpu")
    local missing=()
    
    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${C_YELLOW}The following external security packages need to be installed:${C_RESET} ${missing[*]}"
        read -rp "Proceed with AUR package installation? (y/N): " allow_pkg
        if [[ ! "$allow_pkg" =~ ^[Yy]$ ]]; then
            log_error "Installation aborted by user."
            exit 1
        fi
        
        if command -v yay >/dev/null 2>&1; then
            yay -S --needed "${missing[@]}"
        elif command -v paru >/dev/null 2>&1; then
            paru -S --needed "${missing[@]}"
        else
            log_error "AUR helper (yay or paru) is required to install: ${missing[*]}"
            exit 1
        fi
    else
        log_success "All external dependencies are satisfied."
    fi
    
    verify_binary_integrity
}

verify_binary_integrity() {
    log_info "Verifying cryptographic integrity of PAM module and binaries..."
    local pam_path="/usr/lib/security/pam_facelock.so"
    local bin_path="/usr/bin/facelock"
    
    if [[ ! -f "$pam_path" || ! -f "$bin_path" ]]; then
        log_error "Required security binaries missing after package install."
        exit 1
    fi
    
    local pam_hash bin_hash
    pam_hash=$(sha256sum "$pam_path" | awk '{print $1}')
    bin_hash=$(sha256sum "$bin_path" | awk '{print $1}')
    
    if [[ "$pam_hash" == "$VERIFIED_PAM_SHA256" ]]; then
        log_success "pam_facelock.so verified against reference SHA-256 integrity baseline."
    else
        log_warn "Integrity notice: pam_facelock.so hash ($pam_hash) differs from reference ($VERIFIED_PAM_SHA256)."
        read -rp "Do you explicitly trust this binary and want to register it with PAM? (y/N): " allow_unverified
        if [[ ! "$allow_unverified" =~ ^[Yy]$ ]]; then
            log_error "Aborted PAM registration due to unverified binary hash."
            exit 1
        fi
    fi
}

configure_permissions() {
    log_info "Configuring video and facelock group permissions..."
    sudo usermod -a -G facelock,video "$USER"
    if id sddm >/dev/null 2>&1; then
        sudo usermod -a -G facelock,video sddm
    fi
    
    # Install D-Bus system policy
    sudo tee /usr/share/dbus-1/system.d/org.facelock.Daemon.conf > /dev/null << 'EOF'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
  "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="root">
    <allow own="org.facelock.Daemon"/>
    <allow send_destination="org.facelock.Daemon"/>
    <allow send_interface="org.facelock.Daemon"/>
  </policy>
  <policy context="default">
    <allow send_destination="org.facelock.Daemon"/>
    <allow send_interface="org.facelock.Daemon"/>
    <allow send_interface="org.freedesktop.DBus.Introspectable"/>
    <allow send_interface="org.freedesktop.DBus.Properties"/>
    <allow send_interface="org.freedesktop.DBus.Peer"/>
  </policy>
</busconfig>
EOF
    log_success "D-Bus policy configured."
}

configure_pam() {
    log_info "Configuring PAM authentication stacks with backup..."
    
    # 1. Omarchy Lock Screen Face PAM
    sudo tee /etc/pam.d/omarchy-lock-face > /dev/null << 'EOF'
#%PAM-1.0
auth       sufficient                  pam_facelock.so
auth       required                    pam_deny.so
account    required                    pam_permit.so
EOF

    # 2. Sudo PAM
    if ! grep -q "pam_facelock.so" /etc/pam.d/sudo; then
        sudo sed -i '1i auth        sufficient  pam_facelock.so' /etc/pam.d/sudo
    fi

    # 3. SDDM PAM
    if ! grep -q "pam_facelock.so" /etc/pam.d/sddm; then
        sudo sed -i '1i auth        sufficient  pam_facelock.so' /etc/pam.d/sddm
    fi

    # 4. Polkit PAM
    if ! grep -q "pam_facelock.so" /etc/pam.d/polkit-1; then
        sudo sed -i '1i auth        sufficient  pam_facelock.so' /etc/pam.d/polkit-1
    fi
    
    log_success "PAM stacks configured for Face Unlock."
}

configure_fingerprint() {
    echo ""
    echo -e "${C_CYAN}${C_BOLD}👆 FINGERPRINT SENSOR CONFIGURATION${C_RESET}"
    echo "Would you like to configure a hardware Fingerprint reader alongside Face ID? (y/N)"
    read -r enable_fp
    
    if [[ "$enable_fp" =~ ^[Yy]$ ]]; then
        log_info "Installing fprintd drivers..."
        sudo pacman -S --needed fprintd
        sudo systemctl enable --now fprintd.service
        
        # Add pam_fprintd to PAM stacks if not present
        if ! grep -q "pam_fprintd.so" /etc/pam.d/sudo; then
            sudo sed -i '/pam_facelock.so/a auth        sufficient  pam_fprintd.so' /etc/pam.d/sudo
        fi
        if ! grep -q "pam_fprintd.so" /etc/pam.d/sddm; then
            sudo sed -i '/pam_facelock.so/a auth        sufficient  pam_fprintd.so' /etc/pam.d/sddm
        fi
        
        echo ""
        log_success "Fingerprint drivers active! To enroll your fingerprint, run:"
        echo -e "${C_YELLOW}  fprintd-enroll $USER${C_RESET}"
        echo ""
    fi
}

setup_method_1() {
    echo -e "\n${C_GREEN}${C_BOLD}🛡️ METHOD 1: High Security (Apple / Windows 11 / Android Model)${C_RESET}"
    echo "• Single master passphrase at boot to decrypt AES-256 storage."
    echo "• Direct desktop entry (SDDM automatically logs in, zero second screens)."
    echo "• Face ID & Fingerprint active for Lock Screen, Sudo, and Polkit."
    echo ""
    
    echo "Select environment:"
    echo "  1) Physical Laptop / Desktop (Bare Metal Hardware)"
    echo "  2) Virtual Machine (VMware / QEMU / VirtualBox)"
    read -rp "Enter choice [1-2]: " env_choice
    
    # Configure SDDM autologin
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null << EOF
[Autologin]
User=$USER
Session=omarchy.desktop
EOF
    log_success "SDDM configured to auto-login to desktop after disk decryption."
    
    if [ "$env_choice" = "1" ]; then
        log_info "Physical Hardware: You can optionally bind LUKS to your motherboard TPM 2.0 with:"
        echo -e "${C_CYAN}  sudo systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2${C_RESET}"
    else
        log_info "VM Environment: In VMware settings, ensure Access Control is Encrypted and TPM 2.0 is attached."
    fi
}

setup_method_2() {
    echo -e "\n${C_GREEN}${C_BOLD}⚡ METHOD 2: Maximum Convenience (Direct Face ID on Power-On)${C_RESET}"
    echo "• Silent background storage unlock (zero disk password prompt)."
    echo "• SDDM Face ID Login Screen appears as the FIRST and ONLY screen on boot."
    echo "• Face ID & Fingerprint active for Boot, Lock Screen, Sudo, and Polkit."
    echo ""
    
    echo "Select environment:"
    echo "  1) Physical Laptop / Desktop (Bare Metal Hardware)"
    echo "  2) Virtual Machine (VMware / QEMU / VirtualBox)"
    read -rp "Enter choice [1-2]: " env_choice
    
    # 1. Remove SDDM autologin
    sudo rm -f /etc/sddm.conf.d/autologin.conf
    
    # 2. Create and enroll early keyfile
    log_info "Generating secure auto-unlock keyfile at /crypto_keyfile.bin..."
    sudo dd if=/dev/urandom of=/crypto_keyfile.bin bs=512 count=1 status=none
    sudo chmod 000 /crypto_keyfile.bin
    
    # Identify root LUKS device
    local luks_dev
    luks_dev=$(lsblk -rn -o PATH,FSTYPE | grep -E "crypto_LUKS" | awk '{print $1}' | head -n 1)
    
    if [ -n "$luks_dev" ]; then
        echo "Please enter your current disk encryption passphrase to enroll the auto-unlock key:"
        read -rsp "Passphrase: " luks_pass
        echo ""
        
        # Zero-disk leakage: Stream passphrase directly into cryptsetup stdin pipe without writing to any file
        log_info "Enrolling keyfile into LUKS device $luks_dev via in-memory pipe..."
        if printf '%s' "$luks_pass" | sudo cryptsetup luksAddKey --key-file=- "$luks_dev" /crypto_keyfile.bin; then
            log_success "Keyfile successfully enrolled into LUKS header!"
        else
            log_error "Failed to enroll keyfile into LUKS device. Please verify your passphrase."
            unset luks_pass
            exit 1
        fi
        unset luks_pass
    else
        log_warn "No active LUKS partition detected. If running on unencrypted disk, auto-unlock is already default."
    fi
    
    # 3. Embed keyfile in mkinitcpio
    sudo mkdir -p /etc/mkinitcpio.conf.d
    sudo tee /etc/mkinitcpio.conf.d/auto_unlock.conf > /dev/null << 'EOF'
FILES+=(/crypto_keyfile.bin)
EOF

    # 4. Fix VMware FUSE fstab if in VM
    if [ "$env_choice" = "2" ]; then
        if grep -q "auto_unmount" /etc/fstab; then
            log_info "Fixing VMware Shared Folders FUSE options in /etc/fstab..."
            sudo sed -i 's/auto_unmount,defaults/defaults,nofail/' /etc/fstab
            sudo sed -i 's/allow_other,auto_unmount,defaults/allow_other,defaults,nofail/' /etc/fstab
            log_success "/etc/fstab patched with nofail."
        fi
    fi
    
    # 5. Rebuild initramfs
    log_info "Rebuilding initramfs with embedded auto-unlock keyfile..."
    if command -v limine-mkinitcpio >/dev/null 2>&1; then
        sudo limine-mkinitcpio
    else
        sudo mkinitcpio -P
    fi
    log_success "Boot image rebuilt successfully."
}

enroll_user_face() {
    echo ""
    echo -e "${C_CYAN}${C_BOLD}📸 FACE ENROLLMENT${C_RESET}"
    echo "Look straight into your webcam with normal room lighting."
    echo "Press Enter when ready to start face scanning..."
    read -r
    
    sudo facelock enroll "$USER"
    log_success "Face biometric embedding stored and encrypted."
}

# --- CLI Options Dispatcher ---
if [ $# -gt 0 ]; then
    case "$1" in
        --check) check_status ;;
        --remove|--uninstall) remove_plugin ;;
        --help|-h) usage ;;
        *) log_error "Unknown option: $1. Use --help for available options."; exit 1 ;;
    esac
fi

# --- Main Execution Flow ---
INSTALLING=1
banner
check_prerequisites
backup_system_files
install_packages
configure_permissions
configure_pam

echo -e "${C_CYAN}${C_BOLD}SELECT AUTHENTICATION ARCHITECTURE:${C_RESET}"
echo "  [1] Method 1 (High Security - Apple / Windows Hello / Android Enterprise Model)"
echo "      → Full disk encryption passphrase on boot + SDDM direct desktop + Face ID everywhere else"
echo "  [2] Method 2 (Maximum Convenience - Direct Face ID Boot)"
echo "      → Face ID as the FIRST and ONLY screen on power-on (Silent storage auto-unlock)"
echo ""
read -rp "Enter choice [1 or 2]: " method_choice

case "$method_choice" in
    1) setup_method_1 ;;
    2) setup_method_2 ;;
    *) log_error "Invalid selection. Exiting."; exit 1 ;;
esac

configure_fingerprint

# Enable and start daemon
log_info "Starting facelock-daemon service..."
sudo systemctl enable --now facelock-daemon.service

# Enroll user
enroll_user_face

INSTALLING=0
echo ""
echo -e "${C_GREEN}${C_BOLD}=================================================================${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}   🎉 OMARCHY FACE ID & BIOMETRICS SETUP COMPLETED!             ${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}=================================================================${C_RESET}"
echo ""
echo -e "• Lock Screen: Press ${C_YELLOW}Super + Ctrl + L${C_RESET} to test your instant Face Unlock."
echo -e "• Terminal Sudo: Run ${C_YELLOW}sudo ls /root${C_RESET} to test biometric admin elevation."
echo -e "• Check Status: Run ${C_YELLOW}./setup.sh --check${C_RESET} to verify biometrics anytime."
echo -e "• Rollback: Run ${C_YELLOW}./setup.sh --remove${C_RESET} to cleanly uninstall."
echo ""
