#!/usr/bin/env bash
# Installer for kodi-htpc-remote. Run with sudo on the HTPC.
#   sudo ./install.sh
# Idempotent: re-running updates the files in place.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root: sudo ./install.sh" >&2
    exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
HTPC_USER="${SUDO_USER:-$(id -un 1000)}"
HTPC_HOME="$(getent passwd "$HTPC_USER" | cut -d: -f6)"

echo "==> Target desktop user: $HTPC_USER ($HTPC_HOME)"

echo "==> Dependencies (apt)"
apt-get update -qq
apt-get install -y python3-evdev wmctrl xdotool curl >/dev/null

echo "==> Config"
if [ ! -f /etc/htpc-remote.conf ]; then
    install -m 600 "$SRC/htpc-remote.conf.example" /etc/htpc-remote.conf
    sed -i "s/^HTPC_USER=.*/HTPC_USER=\"$HTPC_USER\"/" /etc/htpc-remote.conf
    echo "    wrote /etc/htpc-remote.conf (edit it to set the Kodi RPC password)"
else
    echo "    /etc/htpc-remote.conf exists, left unchanged"
fi

echo "==> Scripts"
install -d /usr/local/lib/htpc-remote
install -m 644 "$SRC/bin/htpc-common.sh" /usr/local/lib/htpc-remote/htpc-common.sh
install -m 755 "$SRC/bin/htpc-remote" /usr/local/sbin/htpc-remote
install -m 755 "$SRC/bin/htpc-power-key" /usr/local/sbin/htpc-power-key
install -m 755 "$SRC/bin/htpc-focus-kodi" /usr/local/sbin/htpc-focus-kodi
install -m 755 "$SRC/bin/kodi-cache-clean.py" /usr/local/bin/kodi-cache-clean.py
install -D -m 755 "$SRC/bin/htpc-autostart-kodi" "$HTPC_HOME/.local/bin/htpc-autostart-kodi"
chown "$HTPC_USER:$HTPC_USER" "$HTPC_HOME/.local/bin/htpc-autostart-kodi"

echo "==> udev (remap voice/power keys, hide raw device from the desktop)"
install -m 644 "$SRC/udev/70-xiaomi-bt-remote.hwdb" /etc/udev/hwdb.d/70-xiaomi-bt-remote.hwdb
install -m 644 "$SRC/udev/71-xiaomi-bt-remote-libinput.rules" /etc/udev/rules.d/71-xiaomi-bt-remote-libinput.rules
systemd-hwdb update
udevadm trigger

echo "==> systemd units"
install -m 644 "$SRC/systemd/htpc-remote.service" /etc/systemd/system/htpc-remote.service
install -m 644 "$SRC/systemd/kodi-cache-clean@.service" /etc/systemd/system/kodi-cache-clean@.service
install -m 644 "$SRC/systemd/kodi-cache-clean@.timer" /etc/systemd/system/kodi-cache-clean@.timer
systemctl daemon-reload
systemctl enable --now htpc-remote.service
systemctl enable --now "kodi-cache-clean@${HTPC_USER}.timer"

echo "==> Disk / log hardening (keep / from filling up and freezing the desktop)"
install -m 755 "$SRC/bin/htpc-disk-guard" /usr/local/sbin/htpc-disk-guard
install -m 644 "$SRC/systemd/htpc-disk-guard.service" /etc/systemd/system/htpc-disk-guard.service
install -m 644 "$SRC/systemd/htpc-disk-guard.timer" /etc/systemd/system/htpc-disk-guard.timer
install -m 644 "$SRC/rsyslog/10-drop-gnome-shell-gc-spam.conf" /etc/rsyslog.d/10-drop-gnome-shell-gc-spam.conf
install -D -m 644 "$SRC/logrotate/logrotate.timer-hourly.conf" /etc/systemd/system/logrotate.timer.d/hourly.conf
if [ -f /etc/logrotate.d/rsyslog ] && ! grep -q maxsize /etc/logrotate.d/rsyslog; then
    sed -i 's/^\tweekly$/\tweekly\n\tmaxsize 200M/' /etc/logrotate.d/rsyslog
fi
rsyslogd -N1 >/dev/null && systemctl restart rsyslog
systemctl daemon-reload
systemctl enable --now htpc-disk-guard.timer
systemctl restart logrotate.timer

echo "==> GNOME tweaks for a kiosk (disable dock/desktop-icons/tray, no on-screen keyboard)"
runuser -u "$HTPC_USER" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$HTPC_USER")/bus" \
    gsettings set org.gnome.shell disabled-extensions \
    "['ubuntu-dock@ubuntu.com', 'ding@rastersoft.com', 'ubuntu-appindicators@ubuntu.com']" 2>/dev/null \
    || echo "    (run as the desktop user later: see docs/troubleshooting.md)"
runuser -u "$HTPC_USER" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$HTPC_USER")/bus" \
    gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false 2>/dev/null || true

echo "==> Kodi autostart entry"
install -D -m 644 "$SRC/kodi/kodi-autostart.desktop.example" "$HTPC_HOME/.config/autostart/kodi.desktop"
sed -i "s#/home/REPLACE_USER#$HTPC_HOME#" "$HTPC_HOME/.config/autostart/kodi.desktop"
chown -R "$HTPC_USER:$HTPC_USER" "$HTPC_HOME/.config/autostart"

echo
echo "Done. Manual Kodi steps (see docs/kodi-setup.md):"
echo "  - copy kodi/keymaps/remote.xml to ~/.kodi/userdata/keymaps/"
echo "  - copy kodi/addons/service.htpc.youtubeview to ~/.kodi/addons/ and enable it"
echo "  - pair/trust the remote, set GNOME idle+lock, disable sleep targets"
echo "  - set the Kodi RPC password in /etc/htpc-remote.conf"
