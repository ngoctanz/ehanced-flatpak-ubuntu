# Enhanced Flatpak Ubuntu

A transparent post-install setup for Ubuntu GNOME. It replaces Snap with
Flatpak, configures Vietnamese input through Fcitx5, installs common desktop
tools, and performs conservative system cleanup.

> [!WARNING]
> `install.sh` removes every installed Snap, purges `snapd`, and deletes local
> Snap data. Review [What changes](#what-changes) and back up important data
> before running it. This is an independent community project and is not
> affiliated with Ubuntu, Canonical, GNOME, or Flathub.

## Features

- Updates installed APT packages.
- Removes Snap and pins `snapd` to prevent automatic reinstallation.
- Installs Flatpak, Flathub, and GNOME Software.
- Installs Firefox and Thunderbird from Flathub when available.
- Installs Fcitx5 with Unikey and configures autostart.
- Installs common GNOME desktop utilities.
- Cleans unused packages, caches, trash, and old journal entries.
- Provides a `--dry-run` mode for reviewing commands first.

## Requirements

- Ubuntu with GNOME and APT
- An account with `sudo` access
- A working Internet connection
- A current backup, especially on an existing workstation

Other distributions are not supported. The installer warns before continuing
when it does not detect Ubuntu.

## Installation

```bash
git clone https://github.com/ngoctanz/ehanced-flatpak-ubuntu.git
cd ehanced-flatpak-ubuntu
./install.sh --dry-run
./install.sh
```

Use `./install.sh --yes` to accept all prompts. Do not run
`sudo ./install.sh`; the script requests elevated access only for operations
that need it.

Logs are stored as:

```text
~/ubuntu-post-install-YYYYMMDD-HHMMSS.log
```

Reboot after completion to apply the desktop and input-method changes.

## What changes

### APT and Snap

- Runs `apt-get update` and `apt-get full-upgrade`.
- Removes installed Snaps, purges `snapd`, and deletes `/snap`, `/var/snap`,
  `/var/lib/snapd`, `/var/cache/snapd`, and `~/snap`.
- Creates `/etc/apt/preferences.d/nosnap.pref` with Pin-Priority `-10`.

To restore Snap, remove or adjust that pin file, then run:

```bash
sudo apt install snapd
```

### Flatpak and desktop applications

- Installs Flatpak and adds the system-wide Flathub remote.
- Installs GNOME Software and the available Flatpak/firmware plugins.
- Attempts to install `org.mozilla.firefox` and
  `org.mozilla.thunderbird_esr`; unavailable applications are skipped.

### Vietnamese input

- Installs Fcitx5 and `fcitx5-unikey`.
- Removes only `ibus-unikey`, preserving the IBus core required by GNOME.
- Adds Fcitx5 to the current user's autostart directory.

After rebooting, open `fcitx5-configtool` and add Unikey if it is not already
listed.

### Cleanup

- Runs APT `autoremove --purge`, `autoclean`, and `clean`.
- Removes unused Flatpak runtimes.
- Clears thumbnail and IBus caches plus the current user's trash.
- Retains seven days of systemd journal entries.

Feature groups can be enabled or disabled using the Boolean settings near the
top of `install.sh`.

## Backlight troubleshooting

Some laptops select the wrong ACPI backlight interface. Only apply this
workaround when the brightness control is present but does not work.

Test it for one boot before making it permanent:

1. Select Ubuntu in GRUB and press `e`.
2. Find the line beginning with `linux`.
3. Append `acpi_backlight=native`.
4. Press `Ctrl+X` or `F10` to boot.

If brightness control now works:

```bash
./fix-backlight.sh
sudo reboot
```

The script creates
`/etc/default/grub.d/99-enhanced-gnome-backlight.cfg` and runs `update-grub`.
Ubuntu uses this GRUB configuration flow instead of Fedora's common `grubby`
command.

Rollback:

```bash
./fix-backlight.sh --remove
sudo reboot
```

After a kernel update, verify that the parameter was applied:

```bash
cat /proc/cmdline
```

If it is missing, inspect the drop-in file, run `sudo update-grub`, and reboot.
This parameter is not a universal fix; GPU drivers, firmware, and model-specific
kernel support may be responsible instead. See
[issue #1](https://github.com/ngoctanz/ehanced-flatpak-ubuntu/issues/1) and
[issue #2](https://github.com/ngoctanz/ehanced-flatpak-ubuntu/issues/2).

## Troubleshooting

- Find the latest log with `ls -t ~/ubuntu-post-install-*.log | head -1`.
- If Flatpak apps do not appear in GNOME Software, sign out or reboot.
- If Fcitx5 is inactive, check Unikey in `fcitx5-configtool`, then sign in
  again.
- If installation stops, fix the reported error and rerun it. Major steps are
  designed to be safely repeatable.

## Contributing

Issues and pull requests are welcome. Bug reports should include:

- Ubuntu, GNOME, and kernel versions;
- device model and GPU for hardware-related problems;
- the command that was run;
- relevant logs with sensitive information removed.

Run the syntax check before submitting a pull request:

```bash
bash -n install.sh fix-backlight.sh
```

## License

Released under the [MIT License](LICENSE).
