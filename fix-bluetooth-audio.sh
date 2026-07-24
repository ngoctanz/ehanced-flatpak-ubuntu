#!/usr/bin/env bash
set -Eeuo pipefail

readonly DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d"
readonly CONFIG="$DIR/51-bluetooth-a2dp-only.conf"

[[ $EUID -ne 0 ]] || {
  echo "Do not run this script with sudo." >&2
  exit 1
}

if [[ ${1:-} == --remove ]]; then
  rm -f "$CONFIG"
  rmdir --ignore-fail-on-non-empty "$DIR" "$(dirname "$DIR")"
elif (($#)); then
  echo "Usage: $0 [--remove]" >&2
  exit 2
else
  mkdir -p "$DIR"
  printf '%s\n' \
    'monitor.bluez.properties = {' \
    '  bluez5.roles = [ a2dp_sink a2dp_source ]' \
    '}' >"$CONFIG"
fi

systemctl --user restart wireplumber pipewire pipewire-pulse
echo "Bluetooth audio configuration updated."
