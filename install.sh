#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Ubuntu Post-Install Setup
# Community post-install setup for Ubuntu GNOME
#
# Features:
#   - Update the system
#   - Remove Snap and prevent automatic reinstallation
#   - Install Flatpak and Flathub
#   - Install GNOME Software with Flatpak/firmware backends
#   - Install Firefox/Thunderbird from Flathub when available
#   - Install Fcitx5 + Unikey and configure autostart
#   - Safely remove unused packages and caches
#
# Run:
#   chmod +x install.sh
#   ./install.sh
#
# Accept all prompts:
#   ./install.sh --yes
#
# Preview commands without changing the system:
#   ./install.sh --dry-run
# ============================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="$HOME/ubuntu-post-install-$(date +%Y%m%d-%H%M%S).log"

AUTO_YES=false
DRY_RUN=false

# Enable or disable feature groups here.
REMOVE_SNAP=true
INSTALL_FLATPAK=true
INSTALL_GNOME_SOFTWARE=true
INSTALL_DESKTOP_TOOLS=true
INSTALL_FCITX5=true
INSTALL_FLATPAK_APPS=true
CLEAN_SYSTEM=true

# Flatpak app IDs. Apps unavailable on Flathub are skipped.
FLATPAK_APPS=(
  "org.mozilla.firefox"
  "org.mozilla.thunderbird_esr"
)

# Basic desktop packages.
DESKTOP_PACKAGES=(
  curl
  wget
  git
  unzip
  p7zip-full
  build-essential
  gnome-tweaks
  gnome-shell-extension-manager
  fwupd
)

# ------------------------------------------------------------
# Output
# ------------------------------------------------------------

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_BOLD=$'\033[1m'
else
  C_RESET=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_BOLD=""
fi

info()    { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
success() { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()    { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()     { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

section() {
  printf '\n%s============================================================%s\n' "$C_BOLD" "$C_RESET"
  printf '%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"
  printf '%s============================================================%s\n' "$C_BOLD" "$C_RESET"
}

run() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'

  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi

  "$@"
}

run_shell() {
  local command="$1"
  printf '+ %s\n' "$command"

  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi

  bash -c "$command"
}

confirm() {
  local prompt="$1"

  if [[ "$AUTO_YES" == true ]]; then
    return 0
  fi

  read -r -p "$prompt [y/N]: " answer
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

package_available() {
  apt-cache show "$1" >/dev/null 2>&1
}

install_available_packages() {
  local available=()
  local package

  for package in "$@"; do
    if package_available "$package"; then
      available+=("$package")
    else
      warn "APT package not found: $package; skipping."
    fi
  done

  if ((${#available[@]} > 0)); then
    run sudo apt-get install -y "${available[@]}"
  fi
}

# ------------------------------------------------------------
# Error handling
# ------------------------------------------------------------

on_error() {
  local exit_code=$?
  local line_no=$1

  printf '\n%sScript stopped at line %s with exit code %s.%s\n' \
    "$C_RED" "$line_no" "$exit_code" "$C_RESET" >&2
  printf 'Log: %s\n' "$LOG_FILE" >&2
  exit "$exit_code"
}

trap 'on_error "$LINENO"' ERR

# ------------------------------------------------------------
# Arguments
# ------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

  --yes       Accept all prompts
  --dry-run   Print commands without changing the system
  --help      Show this help
EOF
}

while (($# > 0)); do
  case "$1" in
    --yes|-y)
      AUTO_YES=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

# Write output to both the terminal and the log.
exec > >(tee -a "$LOG_FILE") 2>&1

# ------------------------------------------------------------
# System checks
# ------------------------------------------------------------

preflight() {
  section "1. System checks"

  [[ "$EUID" -ne 0 ]] || die "Do not run the entire script with sudo. Use ./$SCRIPT_NAME"

  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "This script targets Ubuntu; detected: ${PRETTY_NAME:-unknown}."
    confirm "Continue?" || exit 0
  else
    success "Detected ${PRETTY_NAME:-Ubuntu}."
  fi

  command_exists apt-get || die "apt-get was not found."
  run sudo -v

  info "Log: $LOG_FILE"
}

# ------------------------------------------------------------
# APT update
# ------------------------------------------------------------

update_system() {
  section "2. Update system"

  run sudo apt-get update
  run sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
}

# ------------------------------------------------------------
# Snap
# ------------------------------------------------------------

remove_snap() {
  [[ "$REMOVE_SNAP" == true ]] || return 0

  section "3. Remove Snap and prevent reinstallation"

  if ! command_exists snap && ! dpkg-query -W -f='${Status}' snapd 2>/dev/null | grep -q 'install ok installed'; then
    success "Snap is already removed."
  else
    warn "All installed Snap applications will be removed."

    if command_exists snap; then
      mapfile -t snap_packages < <(snap list 2>/dev/null | awk 'NR > 1 {print $1}' | tac || true)

      for snap_package in "${snap_packages[@]:-}"; do
        [[ -n "$snap_package" ]] || continue
        run sudo snap remove --purge "$snap_package" || warn "Could not remove Snap: $snap_package"
      done
    fi

    run sudo systemctl disable --now snapd.socket snapd.service snapd.seeded.service 2>/dev/null || true
    run sudo apt-get purge -y snapd
  fi

  run sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd
  run rm -rf "$HOME/snap"

  if [[ "$DRY_RUN" == true ]]; then
    info "Would create /etc/apt/preferences.d/nosnap.pref"
  else
    sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
  fi

  success "Removed and pinned snapd."
}

# ------------------------------------------------------------
# Flatpak
# ------------------------------------------------------------

install_flatpak() {
  [[ "$INSTALL_FLATPAK" == true ]] || return 0

  section "4. Install Flatpak and Flathub"

  install_available_packages flatpak

  run flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo

  run flatpak update --appstream -y
  success "Flatpak and Flathub are ready."
}

# ------------------------------------------------------------
# GNOME Software
# ------------------------------------------------------------

install_gnome_software() {
  [[ "$INSTALL_GNOME_SOFTWARE" == true ]] || return 0

  section "5. Install GNOME Software"

  local packages=(
    gnome-software
    gnome-software-plugin-flatpak
    gnome-software-plugin-fwupd
    fwupd
  )

  # Some Ubuntu releases provide a separate deb plugin; others bundle it.
  if package_available gnome-software-plugin-deb; then
    packages+=(gnome-software-plugin-deb)
  fi

  install_available_packages "${packages[@]}"

  run rm -rf "$HOME/.cache/gnome-software"
  success "Installed GNOME Software with the available backends."
}

# ------------------------------------------------------------
# Desktop tools
# ------------------------------------------------------------

install_desktop_tools() {
  [[ "$INSTALL_DESKTOP_TOOLS" == true ]] || return 0

  section "6. Install desktop tools"

  install_available_packages "${DESKTOP_PACKAGES[@]}"
}

# ------------------------------------------------------------
# Fcitx5
# ------------------------------------------------------------

install_fcitx5() {
  [[ "$INSTALL_FCITX5" == true ]] || return 0

  section "7. Install Fcitx5 + Unikey"

  local fcitx_packages=(
    fcitx5
    fcitx5-unikey
    fcitx5-config-qt
    fcitx5-frontend-gtk3
    fcitx5-frontend-gtk4
    fcitx5-frontend-qt5
    fcitx5-frontend-qt6
    im-config
  )

  install_available_packages "${fcitx_packages[@]}"

  # Remove only the IBus Unikey engine; GNOME still needs the IBus core.
  if dpkg-query -W -f='${Status}' ibus-unikey 2>/dev/null | grep -q 'install ok installed'; then
    run sudo apt-get purge -y ibus-unikey
  fi

  if command_exists im-config; then
    run im-config -n fcitx5
  fi

  run mkdir -p "$HOME/.config/autostart"

  local desktop_file="/usr/share/applications/org.fcitx.Fcitx5.desktop"
  if [[ -f "$desktop_file" ]]; then
    run cp "$desktop_file" "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
  else
    warn "Standard launcher not found; creating one."

    if [[ "$DRY_RUN" == true ]]; then
      info "Would create ~/.config/autostart/fcitx5.desktop"
    else
      cat > "$HOME/.config/autostart/fcitx5.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx 5
Comment=Start Fcitx 5 input method
Exec=/usr/bin/fcitx5
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    fi
  fi

  run rm -rf "$HOME/.cache/ibus"
  success "Fcitx5 installed. Sign out or reboot to apply it."
}

# ------------------------------------------------------------
# Flatpak applications
# ------------------------------------------------------------

install_flatpak_apps() {
  [[ "$INSTALL_FLATPAK_APPS" == true ]] || return 0
  command_exists flatpak || {
    warn "Flatpak is unavailable; skipping Flatpak applications."
    return 0
  }

  section "8. Install applications from Flathub"

  local app

  for app in "${FLATPAK_APPS[@]}"; do
    info "Checking $app..."

    if flatpak remote-info flathub "$app" >/dev/null 2>&1; then
      run flatpak install -y flathub "$app"
    else
      warn "$app is unavailable on Flathub; skipping."
    fi
  done
}

# ------------------------------------------------------------
# System cleanup
# ------------------------------------------------------------

clean_system() {
  [[ "$CLEAN_SYSTEM" == true ]] || return 0

  section "9. Clean the system"

  run sudo apt-get autoremove --purge -y
  run sudo apt-get autoclean
  run sudo apt-get clean

  if command_exists flatpak; then
    run flatpak uninstall --unused -y
  fi

  run rm -rf "$HOME/.cache/thumbnails/"*
  run rm -rf "$HOME/.cache/ibus"
  run rm -rf "$HOME/.local/share/Trash/files/"*
  run rm -rf "$HOME/.local/share/Trash/info/"*

  run sudo journalctl --vacuum-time=7d
  success "Removed unused packages, caches, and old logs."
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

summary() {
  section "Complete"

  cat <<EOF
Ubuntu setup completed.

Next steps:
  1. Reboot the system.
  2. Open fcitx5-configtool and add Unikey if needed.
  3. Check Firefox and Thunderbird in the application list.
  4. Check firmware updates with: fwupdmgr get-updates

Log:
  $LOG_FILE
EOF

  if [[ "$DRY_RUN" == true ]]; then
    warn "Dry-run mode: no changes were applied."
  else
    success "Reboot to finish applying input-method and desktop changes."
  fi
}

main() {
  preflight

  printf '\nThe script will run these feature groups:\n'
  printf '  - System update\n'
  printf '  - Remove Snap: %s\n' "$REMOVE_SNAP"
  printf '  - Flatpak/Flathub: %s\n' "$INSTALL_FLATPAK"
  printf '  - GNOME Software: %s\n' "$INSTALL_GNOME_SOFTWARE"
  printf '  - Fcitx5 + Unikey: %s\n' "$INSTALL_FCITX5"
  printf '  - System cleanup: %s\n\n' "$CLEAN_SYSTEM"

  confirm "Start?" || {
    info "Cancelled."
    exit 0
  }

  update_system
  remove_snap
  install_flatpak
  install_gnome_software
  install_desktop_tools
  install_fcitx5
  install_flatpak_apps
  clean_system
  summary
}

main "$@"
