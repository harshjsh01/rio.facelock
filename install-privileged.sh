#!/usr/bin/env bash
# ==============================================================================
# Omarchy Biometrics Suite: Privileged Installation Stage
# Author: Harsh Joshi
# Plugin ID: rio.facelock
#
# This script executes solely from a root-owned, authenticated snapshot
# (/run/rio-facelock-installer/install-privileged.sh) to eliminate TOCTOU attacks
# and prevent unprivileged tampering with system-wide authentication files.
# ==============================================================================

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: install-privileged.sh must be executed with root authority." >&2
    exit 1
fi

readonly BACKUP_DIR="/etc/omarchy/backup/rio.facelock"

# Output helpers
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'

log_info() { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
log_success() { echo -e "${C_GREEN}[✓ SUCCESS]${C_RESET} $1"; }
log_warn() { echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

backup_system_files() {
    log_info "Creating transactional pre-flight backups in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    
    for stack in sudo sddm polkit-1; do
        if [[ -f "/etc/pam.d/$stack" && ! -f "$BACKUP_DIR/$stack.orig" ]]; then
            cp -p "/etc/pam.d/$stack" "$BACKUP_DIR/$stack.orig"
        fi
    done
}

rollback_on_failure() {
    log_warn "Reverting privileged changes from pre-flight backups..."
    if [[ -d "$BACKUP_DIR" ]]; then
        for stack in sudo sddm polkit-1; do
            if [[ -f "$BACKUP_DIR/$stack.orig" ]]; then
                cp -p "$BACKUP_DIR/$stack.orig" "/etc/pam.d/$stack" 2>/dev/null || true
            fi
        done
    fi
    rm -f /etc/pam.d/omarchy-lock-face 2>/dev/null || true
    rm -f /usr/share/dbus-1/system.d/org.facelock.Daemon.conf 2>/dev/null || true
    systemctl disable --now facelock-daemon.service 2>/dev/null || true
    log_warn "Privileged rollback completed."
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && "${INSTALLING:-0}" -eq 1 ]]; then
        rollback_on_failure
    fi
}
trap cleanup EXIT INT TERM HUP

configure_permissions() {
    local target_user="$1"
    log_info "Configuring groups and D-Bus policies for user: $target_user..."
    usermod -a -G facelock,video "$target_user"
    if id sddm >/dev/null 2>&1; then
        usermod -a -G facelock,video sddm
    fi
    
    cat > /usr/share/dbus-1/system.d/org.facelock.Daemon.conf << 'EOF'
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
    chown root:root /usr/share/dbus-1/system.d/org.facelock.Daemon.conf
    chmod 0644 /usr/share/dbus-1/system.d/org.facelock.Daemon.conf
    log_success "D-Bus policy configured."
}

configure_pam() {
    log_info "Configuring PAM authentication stacks for Face ID..."
    
    # 1. Omarchy Lock Screen Face PAM
    cat > /etc/pam.d/omarchy-lock-face << 'EOF'
#%PAM-1.0
auth       sufficient                  pam_facelock.so
auth       required                    pam_deny.so
account    required                    pam_permit.so
EOF
    chown root:root /etc/pam.d/omarchy-lock-face
    chmod 0644 /etc/pam.d/omarchy-lock-face

    # 2. Sudo PAM
    if [[ -f /etc/pam.d/sudo ]] && ! grep -q "pam_facelock.so" /etc/pam.d/sudo; then
        sed -i '1i auth        sufficient  pam_facelock.so' /etc/pam.d/sudo
    fi

    # 3. SDDM PAM
    if [[ -f /etc/pam.d/sddm ]] && ! grep -q "pam_facelock.so" /etc/pam.d/sddm; then
        sed -i '1i auth        sufficient  pam_facelock.so' /etc/pam.d/sddm
    fi

    # 4. Polkit PAM
    if [[ -f /etc/pam.d/polkit-1 ]] && ! grep -q "pam_facelock.so" /etc/pam.d/polkit-1; then
        sed -i '1i auth        sufficient  pam_facelock.so' /etc/pam.d/polkit-1
    fi
    
    log_success "PAM stacks configured for Face Unlock."
}

configure_fingerprint() {
    local enable_fp="$1"
    if [[ "$enable_fp" == "1" ]]; then
        log_info "Configuring fingerprint reader integration in PAM..."
        if ! pacman -Qi fprintd >/dev/null 2>&1; then
            pacman -S --needed --noconfirm fprintd
        fi
        systemctl enable --now fprintd.service 2>/dev/null || true
        
        if [[ -f /etc/pam.d/sudo ]] && ! grep -q "pam_fprintd.so" /etc/pam.d/sudo; then
            sed -i '/pam_facelock.so/a auth        sufficient  pam_fprintd.so' /etc/pam.d/sudo
        fi
        if [[ -f /etc/pam.d/sddm ]] && ! grep -q "pam_fprintd.so" /etc/pam.d/sddm; then
            sed -i '/pam_facelock.so/a auth        sufficient  pam_fprintd.so' /etc/pam.d/sddm
        fi
        log_success "Fingerprint authentication PAM integration enabled."
    fi
}

configure_service() {
    log_info "Enabling and starting facelock-daemon.service..."
    systemctl daemon-reload
    systemctl enable --now facelock-daemon.service
    log_success "facelock-daemon.service active."
}

remove_privileged() {
    log_info "Stopping and disabling facelock-daemon.service..."
    systemctl disable --now facelock-daemon.service 2>/dev/null || true
    
    log_info "Reverting PAM configurations across sudo, SDDM, and Polkit..."
    rm -f /etc/pam.d/omarchy-lock-face
    
    for stack in sudo sddm polkit-1; do
        if [[ -f "/etc/pam.d/$stack" ]]; then
            sed -i '/pam_facelock.so/d' "/etc/pam.d/$stack"
            sed -i '/pam_fprintd.so/d' "/etc/pam.d/$stack"
        fi
    done
    
    log_info "Removing D-Bus system policy..."
    rm -f /usr/share/dbus-1/system.d/org.facelock.Daemon.conf
    
    # Defensive cleanup of legacy keyfile if present
    if [[ -f /crypto_keyfile.bin ]]; then
        local luks_dev
        luks_dev=$(lsblk -rn -o PATH,FSTYPE 2>/dev/null | grep -E "crypto_LUKS" | awk '{print $1}' | head -n 1 || true)
        if [[ -n "$luks_dev" ]]; then
            cryptsetup luksRemoveKey "$luks_dev" /crypto_keyfile.bin 2>/dev/null || true
        fi
        rm -f /crypto_keyfile.bin
    fi
    if [[ -f /etc/mkinitcpio.conf.d/auto_unlock.conf ]]; then
        rm -f /etc/mkinitcpio.conf.d/auto_unlock.conf
        if command -v limine-mkinitcpio >/dev/null 2>&1; then
            limine-mkinitcpio
        else
            mkinitcpio -P
        fi
    fi
    
    log_success "Privileged configurations cleanly removed."
    exit 0
}

# --- Action Dispatcher ---
ACTION="${1:-}"

case "$ACTION" in
    --install)
        TARGET_USER="${2:-}"
        ENABLE_FP="${3:-0}"
        if [[ -z "$TARGET_USER" ]]; then
            log_error "Target user required for --install."
            exit 1
        fi
        INSTALLING=1
        backup_system_files
        configure_permissions "$TARGET_USER"
        configure_pam
        configure_fingerprint "$ENABLE_FP"
        configure_service
        INSTALLING=0
        ;;
    --remove)
        remove_privileged
        ;;
    *)
        log_error "Unknown action: $ACTION. Supported: --install, --remove."
        exit 1
        ;;
esac
