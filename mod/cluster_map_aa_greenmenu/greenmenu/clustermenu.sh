#!/bin/sh
# clustermenu.sh — the in-cluster menu switch (v0.7.0).
#
#   clustermenu.sh on|off
#
# ON writes GAL_CLUSTER_MENU=1 into the unit's settings copy: the hook
# then routes the steering wheel's SHORT OK press to the player's menu
# overlay (Zoom / Strip / Card / Pump / Hi-res / Exit), the rotary
# navigates, the LONG OK keeps the strip toggle. OFF removes the key:
# the wheel behaves exactly as before (short OK cycles the ETA card,
# long OK the strip, rotary zoom). Lands at the next gal start.
# Requires the v0.7.0 hook; the key is inert for an older one.
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"
case "$1" in
    on|off) : ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write - every form failed:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
CONF="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
echo "app: read-write via '$APP_LADDER_FORM'"

sed -i '/^GAL_CLUSTER_MENU=/d' "$CONF"
case "$1" in
    on)
        echo "GAL_CLUSTER_MENU=1" >> "$CONF"
        echo "Cluster menu: ON. At the next gal start (reboot / phone"
        echo "reconnect): SHORT OK opens the overlay, rotary navigates,"
        echo "OK applies; LONG OK stays the strip toggle."
        ;;
    off)
        echo "Cluster menu: OFF (key removed; the wheel behaves as before)."
        ;;
esac
sync
exit 0
