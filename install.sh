#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Ubuntu Post-Install Setup
# Dành cho Ubuntu GNOME của Tân
#
# Chức năng:
#   - Cập nhật hệ thống
#   - Gỡ Snap và chặn Snap tự cài lại
#   - Cài Flatpak + Flathub
#   - Cài GNOME Software và backend Flatpak/Firmware
#   - Cài Firefox/Thunderbird từ Flathub nếu tồn tại
#   - Cài Fcitx5 + Unikey và tạo autostart
#   - Dọn cache/gói thừa an toàn
#
# Chạy:
#   chmod +x install.sh
#   ./install.sh
#
# Tự động xác nhận:
#   ./install.sh --yes
#
# Chỉ xem các bước, không thay đổi máy:
#   ./install.sh --dry-run
# ============================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="$HOME/ubuntu-post-install-$(date +%Y%m%d-%H%M%S).log"

AUTO_YES=false
DRY_RUN=false

# Có thể bật/tắt từng nhóm tại đây.
REMOVE_SNAP=true
INSTALL_FLATPAK=true
INSTALL_GNOME_SOFTWARE=true
INSTALL_DESKTOP_TOOLS=true
INSTALL_FCITX5=true
INSTALL_FLATPAK_APPS=true
CLEAN_SYSTEM=true

# Flatpak app IDs. App không tồn tại trên Flathub sẽ được bỏ qua.
FLATPAK_APPS=(
  "org.mozilla.firefox"
  "org.mozilla.thunderbird_esr"
)

# Gói tiện ích cơ bản.
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
# Giao diện
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
      warn "Không tìm thấy gói APT: $package — bỏ qua."
    fi
  done

  if ((${#available[@]} > 0)); then
    run sudo apt-get install -y "${available[@]}"
  fi
}

# ------------------------------------------------------------
# Xử lý lỗi
# ------------------------------------------------------------

on_error() {
  local exit_code=$?
  local line_no=$1

  printf '\n%sScript dừng ở dòng %s, mã lỗi %s.%s\n' \
    "$C_RED" "$line_no" "$exit_code" "$C_RESET" >&2
  printf 'Xem log: %s\n' "$LOG_FILE" >&2
  exit "$exit_code"
}

trap 'on_error "$LINENO"' ERR

# ------------------------------------------------------------
# Tham số
# ------------------------------------------------------------

show_help() {
  cat <<EOF
Cách dùng: $SCRIPT_NAME [tùy chọn]

  --yes       Tự động trả lời yes
  --dry-run   Chỉ in lệnh, không thay đổi hệ thống
  --help      Hiện trợ giúp
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
      die "Tham số không hợp lệ: $1"
      ;;
  esac
  shift
done

# Ghi cả màn hình và file log.
exec > >(tee -a "$LOG_FILE") 2>&1

# ------------------------------------------------------------
# Kiểm tra hệ thống
# ------------------------------------------------------------

preflight() {
  section "1. Kiểm tra hệ thống"

  [[ "$EUID" -ne 0 ]] || die "Không chạy toàn bộ script bằng sudo. Hãy dùng ./$SCRIPT_NAME"

  [[ -r /etc/os-release ]] || die "Không đọc được /etc/os-release."
  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "Script được viết cho Ubuntu, hệ hiện tại là: ${PRETTY_NAME:-không rõ}."
    confirm "Tiếp tục?" || exit 0
  else
    success "Phát hiện ${PRETTY_NAME:-Ubuntu}."
  fi

  command_exists apt-get || die "Không tìm thấy apt-get."
  run sudo -v

  info "Log được lưu tại: $LOG_FILE"
}

# ------------------------------------------------------------
# Cập nhật APT
# ------------------------------------------------------------

update_system() {
  section "2. Cập nhật hệ thống"

  run sudo apt-get update
  run sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
}

# ------------------------------------------------------------
# Snap
# ------------------------------------------------------------

remove_snap() {
  [[ "$REMOVE_SNAP" == true ]] || return 0

  section "3. Gỡ Snap và chặn cài lại"

  if ! command_exists snap && ! dpkg-query -W -f='${Status}' snapd 2>/dev/null | grep -q 'install ok installed'; then
    success "Snap đã được gỡ trước đó."
  else
    warn "Các ứng dụng Snap sẽ bị gỡ khỏi máy."

    if command_exists snap; then
      mapfile -t snap_packages < <(snap list 2>/dev/null | awk 'NR > 1 {print $1}' | tac || true)

      for snap_package in "${snap_packages[@]:-}"; do
        [[ -n "$snap_package" ]] || continue
        run sudo snap remove --purge "$snap_package" || warn "Không gỡ được Snap: $snap_package"
      done
    fi

    run sudo systemctl disable --now snapd.socket snapd.service snapd.seeded.service 2>/dev/null || true
    run sudo apt-get purge -y snapd
  fi

  run sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd
  run rm -rf "$HOME/snap"

  if [[ "$DRY_RUN" == true ]]; then
    info "Sẽ tạo /etc/apt/preferences.d/nosnap.pref"
  else
    sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
  fi

  success "Đã gỡ và pin snapd."
}

# ------------------------------------------------------------
# Flatpak
# ------------------------------------------------------------

install_flatpak() {
  [[ "$INSTALL_FLATPAK" == true ]] || return 0

  section "4. Cài Flatpak và Flathub"

  install_available_packages flatpak

  run flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo

  run flatpak update --appstream -y
  success "Flatpak và Flathub đã sẵn sàng."
}

# ------------------------------------------------------------
# GNOME Software
# ------------------------------------------------------------

install_gnome_software() {
  [[ "$INSTALL_GNOME_SOFTWARE" == true ]] || return 0

  section "5. Cài GNOME Software"

  local packages=(
    gnome-software
    gnome-software-plugin-flatpak
    gnome-software-plugin-fwupd
    fwupd
  )

  # Một số bản Ubuntu có plugin deb riêng, một số bản tích hợp sẵn.
  if package_available gnome-software-plugin-deb; then
    packages+=(gnome-software-plugin-deb)
  fi

  install_available_packages "${packages[@]}"

  run rm -rf "$HOME/.cache/gnome-software"
  success "GNOME Software đã được cài cùng backend khả dụng."
}

# ------------------------------------------------------------
# Công cụ desktop
# ------------------------------------------------------------

install_desktop_tools() {
  [[ "$INSTALL_DESKTOP_TOOLS" == true ]] || return 0

  section "6. Cài tiện ích desktop"

  install_available_packages "${DESKTOP_PACKAGES[@]}"
}

# ------------------------------------------------------------
# Fcitx5
# ------------------------------------------------------------

install_fcitx5() {
  [[ "$INSTALL_FCITX5" == true ]] || return 0

  section "7. Cài Fcitx5 + Unikey"

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

  # Chỉ gỡ engine Unikey của IBus; giữ IBus core để không phá GNOME.
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
    warn "Không tìm thấy launcher chuẩn; tạo launcher thủ công."

    if [[ "$DRY_RUN" == true ]]; then
      info "Sẽ tạo ~/.config/autostart/fcitx5.desktop"
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
  success "Fcitx5 đã được cài. Cần đăng xuất hoặc reboot để áp dụng."
}

# ------------------------------------------------------------
# Ứng dụng Flatpak
# ------------------------------------------------------------

install_flatpak_apps() {
  [[ "$INSTALL_FLATPAK_APPS" == true ]] || return 0
  command_exists flatpak || {
    warn "Không có Flatpak; bỏ qua ứng dụng Flatpak."
    return 0
  }

  section "8. Cài ứng dụng từ Flathub"

  local app

  for app in "${FLATPAK_APPS[@]}"; do
    info "Kiểm tra $app..."

    if flatpak remote-info flathub "$app" >/dev/null 2>&1; then
      run flatpak install -y flathub "$app"
    else
      warn "$app không tồn tại trên Flathub hiện tại — bỏ qua."
    fi
  done
}

# ------------------------------------------------------------
# Dọn hệ thống
# ------------------------------------------------------------

clean_system() {
  [[ "$CLEAN_SYSTEM" == true ]] || return 0

  section "9. Dọn hệ thống an toàn"

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
  success "Đã dọn cache, gói thừa và log cũ."
}

# ------------------------------------------------------------
# Tổng kết
# ------------------------------------------------------------

summary() {
  section "Hoàn tất"

  cat <<EOF
Đã chạy xong cấu hình Ubuntu.

Việc nên làm tiếp:
  1. Reboot máy.
  2. Mở fcitx5-configtool và thêm Unikey nếu chưa có.
  3. Kiểm tra Firefox/Thunderbird trong danh sách ứng dụng.
  4. Kiểm tra firmware bằng: fwupdmgr get-updates

Log:
  $LOG_FILE
EOF

  if [[ "$DRY_RUN" == true ]]; then
    warn "Đây là chế độ dry-run; chưa có thay đổi nào được áp dụng."
  else
    success "Nên reboot để hoàn tất thay đổi input method và desktop session."
  fi
}

main() {
  preflight

  printf '\nScript sẽ thực hiện các nhóm sau:\n'
  printf '  - Update hệ thống\n'
  printf '  - Gỡ Snap: %s\n' "$REMOVE_SNAP"
  printf '  - Flatpak/Flathub: %s\n' "$INSTALL_FLATPAK"
  printf '  - GNOME Software: %s\n' "$INSTALL_GNOME_SOFTWARE"
  printf '  - Fcitx5 + Unikey: %s\n' "$INSTALL_FCITX5"
  printf '  - Dọn hệ thống: %s\n\n' "$CLEAN_SYSTEM"

  confirm "Bắt đầu?" || {
    info "Đã hủy."
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
