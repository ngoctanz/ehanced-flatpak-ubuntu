#!/usr/bin/env bash
set -Eeuo pipefail

readonly CONFIG=/etc/default/grub.d/99-enhanced-gnome-backlight.cfg

[[ $EUID -ne 0 ]] || {
  echo "Không chạy script bằng sudo; hãy dùng: ./fix-backlight.sh" >&2
  exit 1
}
command -v update-grub >/dev/null || {
  echo "Không tìm thấy update-grub. Script này chỉ hỗ trợ Ubuntu dùng GRUB." >&2
  exit 1
}

if [[ ${1:-} == --remove ]]; then
  sudo rm -f "$CONFIG"
  sudo update-grub
  echo "Đã gỡ acpi_backlight=native. Hãy reboot."
elif (($#)); then
  echo "Cách dùng: $0 [--remove]" >&2
  exit 2
else
  printf '%s\n' \
    '# Added by Enhanced GNOME; remove this file to undo.' \
    'GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} acpi_backlight=native"' |
    sudo tee "$CONFIG" >/dev/null
  sudo update-grub
  echo "Đã thêm acpi_backlight=native. Hãy reboot."
fi
