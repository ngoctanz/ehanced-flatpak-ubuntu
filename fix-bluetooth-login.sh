#!/usr/bin/env bash
set -Eeuo pipefail

readonly CONFIG=/var/lib/gdm3/.config/wireplumber/wireplumber.conf.d/10-disable-bluetooth.conf

[[ $EUID -ne 0 ]] || {
  echo "Do not run this script with sudo; use: ./fix-bluetooth-login.sh" >&2
  exit 1
}
command -v wireplumber >/dev/null || {
  echo "wireplumber was not found." >&2
  exit 1
}
[[ -d /var/lib/gdm3 ]] || {
  echo "GDM was not found. This workaround only supports GDM." >&2
  exit 1
}

if [[ ${1:-} == --remove ]]; then
  sudo rm -f "$CONFIG"
  echo "Removed the GDM Bluetooth workaround. Reboot to apply the change."
elif (($#)); then
  echo "Usage: $0 [--remove]" >&2
  exit 2
else
  sudo install -d -m 755 "$(dirname "$CONFIG")"
  printf '%s\n' \
    'wireplumber.profiles = {' \
    '  main = {' \
    '    hardware.bluetooth = disabled' \
    '  }' \
    '}' |
    sudo tee "$CONFIG" >/dev/null
  echo "Disabled Bluetooth audio in GDM. Reboot to apply the change."
fi
