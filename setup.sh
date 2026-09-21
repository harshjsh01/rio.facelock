#!/usr/bin/env bash
# ==============================================================================
# Omarchy Biometrics Suite: Face ID & Fingerprint
# Author: Harsh Joshi
# Plugin ID: rio.facelock
# Version: 1.0.0
# Description: Production-grade Face Unlock & Fingerprint for Omarchy Linux
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pinned immutable package and binary integrity baseline (facelock-bin 0.1.4-1)
readonly VERIFIED_FACELOCK_VERSION="0.1.4-1"
readonly VERIFIED_FACELOCK_COMMIT="2a3cec6462cdd0ee7ca3bc352dfeb8b46ab2f7f5"
readonly VERIFIED_PKGBUILD_SHA256="820aaa652284a0c3328048d635e4b6a8320a2c12b858270c2f9bfbcdf1cc3f8b"
readonly VERIFIED_PAM_SHA256="ca4e525b1a70fbb620e47af81b6df3bfd90166c260b546ea846fd8ca8f8da1a3"
readonly VERIFIED_BIN_SHA256="b87dbf72540f3aa90b8682cb0c7efefec2c9643cf09d8da4a036a34b5bc8061e"
readonly VERIFIED_POLKIT_SHA256="17a11c9c8dbf8c09cc6eb3e27775cb6193b18c8727e4c648bd23ac0fdfd6fceb"
readonly VERIFIED_PRIVILEGED_STAGE_SHA256="0a60ffdf0e27a541c57d46db8e2bcf4218994e7d07621a732fe63f16a222bb95"

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_PURPLE='\033[0;35m'

cleanup() {
    if [[ -n "${BUILD_TMP_DIR:-}" && -d "${BUILD_TMP_DIR:-}" ]]; then
        rm -rf "$BUILD_TMP_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM HUP

banner() {
    clear
    echo -e "${C_CYAN}${C_BOLD}"
    echo "  ██████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗"
    echo " ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝"
    echo " ██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ "
    echo " ██║   ██║██║╚██╔╝██║██╔══██╗██╔══██╗██║     ██╔══██║  ╚██╔╝  "
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
  --remove       Cleanly uninstall rio.facelock, restore original PAM stacks, and clean policies.
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
        local installed_ver
        installed_ver=$(pacman -Q facelock-bin | awk '{print $2}')
        if [[ "$installed_ver" == "$VERIFIED_FACELOCK_VERSION" ]]; then
            echo -e "${C_GREEN}Installed and Verified ($installed_ver)${C_RESET}"
        else
            echo -e "${C_YELLOW}Installed ($installed_ver) - Version mismatch with baseline ($VERIFIED_FACELOCK_VERSION)${C_RESET}"
        fi
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

    echo -n "PAM Polkit face unlock: "
    if grep -q "pam_facelock.so" /etc/pam.d/polkit-1 2>/dev/null; then
        echo -e "${C_GREEN}Configured${C_RESET}"
    else
        echo -e "${C_YELLOW}Not configured${C_RESET}"
    fi
    
    exit 0
}

check_prerequisites() {
    log_info "Verifying host system compatibility..."
    
    if ! command -v pacman >/dev/null 2>&1; then
        log_error "This suite requires Arch Linux or Omarchy."
        exit 1
    fi
    
    if ls /dev/video* >/dev/null 2>&1; then
        log_success "Webcam detected: $(ls -d /dev/video* | tr '\n' ' ')"
    else
        log_warn "No video devices found at /dev/video*. Biometrics will require a camera before authentication."
    fi
}

install_packages() {
    log_info "Verifying core AI face recognition dependencies..."
    
    # 1. Onnxruntime from official Arch repositories (GPG signed)
    if ! pacman -Qi onnxruntime-cpu >/dev/null 2>&1 && ! pacman -Qi onnxruntime >/dev/null 2>&1; then
        log_info "Installing signed onnxruntime-cpu from official Arch repositories..."
        sudo pacman -S --needed --noconfirm onnxruntime-cpu
    fi
    
    # 2. Immutable facelock-bin package verification & installation
    if pacman -Qi facelock-bin >/dev/null 2>&1; then
        local current_ver
        current_ver=$(pacman -Q facelock-bin | awk '{print $2}')
        if [[ "$current_ver" != "$VERIFIED_FACELOCK_VERSION" ]]; then
            log_error "Installed facelock-bin version ($current_ver) does not match pinned immutable version ($VERIFIED_FACELOCK_VERSION)."
            log_error "Security policy fails closed to prevent unverified PAM binaries from entering authentication stacks."
            exit 1
        fi
        log_success "Existing facelock-bin matches pinned version ($current_ver)."
    else
        log_info "Building facelock-bin from immutable git commit ($VERIFIED_FACELOCK_COMMIT)..."
        BUILD_TMP_DIR=$(mktemp -d /tmp/facelock-build.XXXXXX)
        git clone https://aur.archlinux.org/facelock-bin.git "$BUILD_TMP_DIR"
        (
            cd "$BUILD_TMP_DIR"
            git checkout "$VERIFIED_FACELOCK_COMMIT"
            
            # Verify PKGBUILD checksum against pinned hash
            local pkgbuild_hash
            pkgbuild_hash=$(sha256sum PKGBUILD | awk '{print $1}')
            if [[ "$pkgbuild_hash" != "$VERIFIED_PKGBUILD_SHA256" ]]; then
                echo -e "${C_RED}[ERROR] PKGBUILD checksum mismatch!${C_RESET}" >&2
                echo -e "Expected: $VERIFIED_PKGBUILD_SHA256" >&2
                echo -e "Got:      $pkgbuild_hash" >&2
                exit 1
            fi
            
            makepkg -si --noconfirm
        )
        rm -rf "$BUILD_TMP_DIR"
        unset BUILD_TMP_DIR
    fi
    
    verify_binary_integrity
}

verify_binary_integrity() {
    log_info "Enforcing fail-closed cryptographic integrity verification for PAM modules and binaries..."
    
    local pam_path="/usr/lib/security/pam_facelock.so"
    local bin_path="/usr/bin/facelock"
    local polkit_path="/usr/bin/facelock-polkit-agent"
    
    if [[ ! -f "$pam_path" || ! -f "$bin_path" || ! -f "$polkit_path" ]]; then
        log_error "Required security binaries missing after package install."
        exit 1
    fi
    
    local pam_hash bin_hash polkit_hash
    pam_hash=$(sha256sum "$pam_path" | awk '{print $1}')
    bin_hash=$(sha256sum "$bin_path" | awk '{print $1}')
    polkit_hash=$(sha256sum "$polkit_path" | awk '{print $1}')
    
    # 1. PAM module check
    if [[ "$pam_hash" != "$VERIFIED_PAM_SHA256" ]]; then
        log_error "Cryptographic verification FAILED for $pam_path!"
        log_error "Expected: $VERIFIED_PAM_SHA256"
        log_error "Got:      $pam_hash"
        log_error "Failing closed immediately. Unverified binaries will not be registered with PAM."
        exit 1
    fi
    log_success "pam_facelock.so verified against reference SHA-256."
    
    # 2. Daemon binary check
    if [[ "$bin_hash" != "$VERIFIED_BIN_SHA256" ]]; then
        log_error "Cryptographic verification FAILED for $bin_path!"
        log_error "Expected: $VERIFIED_BIN_SHA256"
        log_error "Got:      $bin_hash"
        log_error "Failing closed immediately."
        exit 1
    fi
    log_success "facelock binary verified against reference SHA-256."
    
    # 3. Polkit agent check
    if [[ "$polkit_hash" != "$VERIFIED_POLKIT_SHA256" ]]; then
        log_error "Cryptographic verification FAILED for $polkit_path!"
        log_error "Expected: $VERIFIED_POLKIT_SHA256"
        log_error "Got:      $polkit_hash"
        log_error "Failing closed immediately."
        exit 1
    fi
    log_success "facelock-polkit-agent verified against reference SHA-256."
}

run_privileged_stage() {
    local stage_dir="/run/rio-facelock-installer"
    local stage_script="$stage_dir/install-privileged.sh"
    
    log_info "Creating root-owned execution staging directory at $stage_dir..."
    sudo mkdir -p -m 0700 "$stage_dir"
    sudo chown root:root "$stage_dir"
    
    sudo cp -p "$SCRIPT_DIR/install-privileged.sh" "$stage_script"
    sudo chown root:root "$stage_script"
    sudo chmod 0700 "$stage_script"
    
    log_info "Authenticating privileged stage digest against pinned hash..."
    local staged_hash
    staged_hash=$(sudo sha256sum "$stage_script" | awk '{print $1}')
    if [[ "$staged_hash" != "$VERIFIED_PRIVILEGED_STAGE_SHA256" ]]; then
        log_error "Privileged stage digest authentication FAILED!"
        log_error "Expected: $VERIFIED_PRIVILEGED_STAGE_SHA256"
        log_error "Got:      $staged_hash"
        sudo rm -rf "$stage_dir"
        exit 1
    fi
    log_success "Privileged stage authenticated ($staged_hash)."
    log_info "Executing privileged installation from root-owned snapshot..."
    
    if ! sudo "$stage_script" "$@"; then
        log_error "Privileged installation stage failed."
        sudo rm -rf "$stage_dir"
        exit 1
    fi
    
    sudo rm -rf "$stage_dir"
    log_success "Privileged stage finished and root snapshot cleaned."
}

remove_plugin() {
    banner
    echo -e "${C_YELLOW}${C_BOLD}⚠️  REMOVING RIO.FACELOCK BIOMETRICS SUITE${C_RESET}\n"
    read -rp "Are you sure you want to remove Face ID and restore default authentication? (y/N): " confirm_rm
    if [[ ! "$confirm_rm" =~ ^[Yy]$ ]]; then
        log_info "Aborted removal."
        exit 0
    fi
    
    run_privileged_stage --remove
    log_success "rio.facelock completely uninstalled. System successfully restored to default!"
    exit 0
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
banner
check_prerequisites
install_packages

echo ""
echo -e "${C_CYAN}${C_BOLD}👆 FINGERPRINT SENSOR CONFIGURATION${C_RESET}"
echo "Would you like to configure a hardware Fingerprint reader alongside Face ID? (y/N)"
read -r enable_fp
ENABLE_FP=0
if [[ "$enable_fp" =~ ^[Yy]$ ]]; then
    ENABLE_FP=1
fi

# Execute all privileged changes from root-owned, authenticated snapshot
run_privileged_stage --install "$USER" "$ENABLE_FP"

# Enroll user biometric data
enroll_user_face

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
