#!/usr/bin/env bash
set -Eeuo pipefail

readonly CONFIG=/etc/default/grub.d/99-enhanced-gnome-backlight.cfg

[[ $EUID -ne 0 ]] || {
  echo "Do not run this script with sudo; use: ./fix-backlight.sh" >&2
  exit 1
}
command -v update-grub >/dev/null || {
  echo "update-grub was not found. This script supports Ubuntu systems using GRUB." >&2
  exit 1
}

if [[ ${1:-} == --remove ]]; then
  sudo rm -f "$CONFIG"
  sudo update-grub
  echo "Removed acpi_backlight=native. Reboot to apply the change."
elif (($#)); then
  echo "Usage: $0 [--remove]" >&2
  exit 2
else
  printf '%s\n' \
    '# Added by Enhanced GNOME; remove this file to undo.' \
    'GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} acpi_backlight=native"' |
    sudo tee "$CONFIG" >/dev/null
  sudo update-grub
  echo "Added acpi_backlight=native. Reboot to apply the change."
fi
