#!/usr/bin/env bash
set -euo pipefail

# Ensure we have root privileges before touching system paths.
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Resolve the active GRUB theme's icons directory from user.cfg.
find_icons_dir() {
  local theme_line theme_dir
  theme_line="$(awk -F= '/set[[:space:]]+theme=/ {print $2; exit}' /boot/grub2/user.cfg 2>/dev/null | tr -d '"' || true)"
  [[ -n "$theme_line" ]] || return 1
  theme_dir="${theme_line%/*}"
  echo "${theme_dir}/icons"
}

icons_dir="$(find_icons_dir || true)"

# Abort (soft) if we cannot locate the theme icons directory.
if [[ -z "$icons_dir" || ! -d "$icons_dir" ]]; then
  echo "Could not find GRUB theme icons directory. Ensure /boot/grub2/user.cfg contains a theme= entry. Skipping." >&2
  exit 3
fi

# Drop the Bluefin icon into the active theme.
echo "Copying Bluefin icon to ${icons_dir}"
install -m 644 -D "${script_dir}/bluefin.png" "${icons_dir}/bluefin.png"

# Install the helper that ensures grub_class bluefin exists.
echo "Installing helper script to /usr/local/sbin"
install -m 755 "${script_dir}/bls-add-bluefin.sh" /usr/local/sbin/bls-add-bluefin.sh

# Add the rpm-ostree hook and reload systemd.
echo "Installing systemd drop-in for rpm-ostree hook"
install -m 644 -D "${script_dir}/bluefin-icons.conf" /etc/systemd/system/ostree-finalize-staged.service.d/bluefin-icons.conf
systemctl daemon-reload

# Immediately apply the Bluefin class to existing BLS entries.
echo "Applying grub_class bluefin to existing BLS entries"
/usr/local/sbin/bls-add-bluefin.sh

# Report completion.
echo "Done. New deployments will keep the Bluefin GRUB icon."
